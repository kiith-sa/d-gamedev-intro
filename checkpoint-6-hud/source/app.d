//          Copyright Ferdinand Majerech 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

import std.stdio;
import std.algorithm: canFind, count, filter, min, remove; // (1)
import std.math: fmod, PI; // (2)
import gfm.math, gfm.sdl2; // (3)
import std.logger; // std.experimental.logger in newer versions


// Compile-time constants
enum vec2i gameArea  = vec2i(800, 600);
enum vec2f gameAreaF = vec2f(800.0f, 600.0f);

struct GamePlatform
{
    SDL2 sdl2;             // Main SDL2 library, wrapped by gfm
    SDLTTF sdlttf;         // SDL2 extension for font handling
    SDL2Window window;     // Main game window
    SDL2Renderer renderer; // Simple SDL2 builtin 2D renderer
    SDLFont font;          // Font for our game

    // Disable the default constructor
    @disable this();

    this(Logger log)
    {
        sdl2   = new SDL2(log);
        scope(failure) { sdl2.close(); }
        sdlttf = new SDLTTF(sdl2);
        scope(failure) { sdlttf.close(); }

        // Hide mouse cursor
        SDL_ShowCursor(SDL_DISABLE);

        // Open the game window.
        const windowFlags = SDL_WINDOW_SHOWN | SDL_WINDOW_INPUT_FOCUS | SDL_WINDOW_MOUSE_FOCUS;
        window = new SDL2Window(sdl2, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                                gameArea.x, gameArea.y, windowFlags);
        scope(failure) { window.close(); }

        // SDL renderer. For 2D drawing, this is easier to use than OpenGL.
        renderer = new SDL2Renderer(window, SDL_RENDERER_ACCELERATED); // SDL_RENDERER_SOFTWARE
        scope(failure) { renderer.close(); }

        // Load the font.
        import std.file: thisExePath;
        import std.path: buildPath, dirName;
        font = new SDLFont(sdlttf, thisExePath.dirName.buildPath("DroidSans.ttf"), 20);
        scope(failure) { font.close(); }
    }

    ~this()
    {
        font.close();
        renderer.close();
        window.close();
        sdlttf.close();
        sdl2.close();
    }
}

struct Entity
{
    enum Type: ubyte
    {
        Player,
        Projectile,
        AsteroidBig, AsteroidMed, AsteroidSmall
    }

    static immutable typeRadius = [10.0f, 3.0f, 20.0f, 13.0f, 8.0f];
    static immutable typeDebrisCount = [0, 0, 2, 2, 0];
    static immutable typeDebrisType  = [Type.init, Type.init, Type.AsteroidMed, Type.AsteroidSmall, Type.init];

    Type debrisType()  const { return typeDebrisType[type]; }
    uint debrisCount() const { return typeDebrisCount[type]; }


    // Entity type (player, asteroid, etc.)
    Type type;
    // 2D (float) position of the entity.
    vec2f pos;
    // Speed of the entity (X and Y) in units per second.
    vec2f speed = vec2f(0.0f, 0.0f);
    // Rotation of the entity.
    float rotRadians = 0.0f;

    // Acceleration in units per second ** 2 (used by player)
    float acceleration = 0.0f;
    // Turn speed in radians per second (used by player)
    float turnSpeed  = 0.0f;

    // Is the entity dead?
    bool dead = false;

    float radius() const { return typeRadius[type]; }
}

Entity createPlayer()
{
    // Any number of struct members may be set directly at initialization without a constructor.
    auto result = Entity(Entity.Type.Player, vec2f(0.5f, 0.5f) * gameAreaF);
    // Can't set these at initialization without setting all preceding members.
    result.acceleration = 150.0f;
    result.turnSpeed    = 3.5f;
    return result;
}

void entityCollisions(Entity[] objects)
{
    // This is a really stupid way of handling collisions (O(n**2))
    foreach(i, ref o1; objects) foreach(ref o2; objects[i + 1 .. $])
    {
        if((o1.pos - o2.pos).squaredLength < o1.radius ^^ 2 + o2.radius ^^ 2)
        {
            o1.dead = o2.dead = true;
        }
    }
}

Entity[] entityDeaths(Entity[] objects, ref uint lives)
{
    foreach(ref object; objects.filter!((ref o) => o.dead))
    {
        if(object.type == Entity.Type.Player && --lives > 0)
        {
            object = createPlayer();
        }

        foreach(d; 0 .. object.debrisCount)
        {
            objects ~= createDebris(object, objects);
        }
    }

    return objects.remove!((ref o) => o.dead);
}

Entity createProjectile(ref Entity shooter)
{
    auto result = Entity(Entity.Type.Projectile);
    const direction = shooter.rotRadians.directionVector;
    // Ensure the projectile gets spawned outside the shooter's collision radius.
    result.pos        = shooter.pos + direction * (shooter.radius + result.radius) * 1.5;
    // Speed of the projectile is added to the shooter's speed.
    result.speed      = shooter.speed + direction * 400.0;
    result.rotRadians = shooter.rotRadians;
    return result;
}

// Class, GC allocated, without RAII (by default) - like Java/C# classes
class GameState
{
private:
    // Index of the player entity in objects.
    size_t playerIndex;

public:
    enum Phase
    {
        Playing,
        GameOver
    }

    Phase phase = Phase.Playing;

    uint lives = 3;

    uint round = 0;

    Entity[] objects;

    float frameTimeSecs = 0.0f;

    this()
    {
        objects = [createPlayer()];
        playerIndex = 0;
        // Reserve to avoid (GC) reallocations
        objects.reserve(100);
    }

    ref Entity player()
    {
        assert(phase == Phase.Playing, "Can't access the player ship; game is over");
        return objects[playerIndex];
    }
}


void renderObject(SDL2Renderer renderer, Entity.Type type, vec2f pos, float rot, float radius)
{
    enum h = 1.0f;
    static vec2f[] vertices = [vec2f(-h, -h), vec2f(h, -h),
                               vec2f(h,  -h), vec2f(h, h),
                               vec2f(h,  h),  vec2f(-h, h),
                               vec2f(-h, h),  vec2f(-h, -h)];

    // Matrix to rotate vertices
    const rotation = mat3f.rotateZ(rot);
    import std.range: chunks;
    // Iterate by pairs of points (start/end points of each line).
    foreach(line; vertices.chunks(2))
    {
        // First scale vertices by radius, then rotate them, and then move (translate)
        // them into position. Rotation needs a 3D vector, so we add a 0 and later
        // discard the 3rd coordinate (only using X,Y).
        const s = pos + (rotation * vec3f(radius * line[0], 0)).xy;
        const e = pos + (rotation * vec3f(radius * line[1], 0)).xy;
        // SDL renderer requires integer coords
        renderer.drawLine(cast(int)s.x, cast(int)s.y, cast(int)e.x, cast(int)e.y);
    }
}

void entityRendering(Entity[] objects, SDL2Renderer renderer)
{
    foreach(ref object; objects)
    {
        // renderObject() used with UFCS as an external method of Renderer
        renderer.renderObject(object.type, object.pos, object.rotRadians, object.radius);
    }
}


void entityMovement(Entity[] objects, float frameTime)
{
    foreach(ref object; objects)
    {
        // Need to multiply by frameTime to determine how much to move the object.
        object.pos += frameTime * object.speed;
        // Wrap the positions around (object that leaves the right edge enters the left endge)
        // fmod() is compatible with C fmod(), i.e. not really modulo for negative numbers.
        auto modulo = (float a, float b) => a >= 0 ? fmod(a, b) : fmod(a,b) + b;
        object.pos.x = modulo(object.pos.x, gameAreaF.x);
        object.pos.y = modulo(object.pos.y, gameAreaF.y);
    }
}

vec2f directionVector(float radians)
{
    // Rotates an up vector around Z in 3D, and returns the X/Y coords of that.
    return (mat3f.rotateZ(radians) * vec3f(0.0f, -1.0f, 0.0f)).xy;
}

bool handleInput(ref GameState game)
{
    SDL_Event event;
    while(SDL_PollEvent(&event))
    {
        if(event.type == SDL_QUIT) { return false; }

        // Ignore repeated events when the key is being held
        if(event.type == SDL_KEYDOWN && !event.key.repeat)
        {
            switch(event.key.keysym.scancode)
            {
                case SDL_SCANCODE_SPACE:
                    if(game.phase == GameState.Phase.Playing)
                    {
                        game.objects ~= createProjectile(game.player);
                    }
                    break;
                default: break;
            }
        }
    }

    int keysLen;
    // C API function, returns a pointer.
    const ubyte* keysPtr = SDL_GetKeyboardState(&keysLen);
    // Bounded slice for safety
    const keys = keysPtr[0 .. keysLen];

    // Player ship controls.


    if(game.phase == GameState.Phase.Playing) with(game.player)
    {
        if(keys[SDL_SCANCODE_UP])
        {
            speed += game.frameTimeSecs * acceleration * rotRadians.directionVector;
        }
        if(keys[SDL_SCANCODE_LEFT])  { rotRadians -= game.frameTimeSecs * turnSpeed; }
        if(keys[SDL_SCANCODE_RIGHT]) { rotRadians += game.frameTimeSecs * turnSpeed; }
    }

    return true;
}

import std.random: uniform;
Entity createAsteroid(Entity[] objects)
{
    auto result = Entity(Entity.Type.AsteroidBig);
    result.rotRadians = uniform(0.0f, 2 * PI);
    result.speed = result.rotRadians.directionVector * uniform(30.0f, 90.0f);
    // Try to create an asteroid that doesn't collide with anything, give up after
    // 10 attempts if we can't so we don't loop infinitely if the game area is full.
    foreach(attempt; 0 .. 10)
    {
        result.pos = vec2f(uniform(0.0f, 1.0f), uniform(0.0f, 1.0f)) * gameAreaF;
        // If we can't find any object that collides with result, we have a good position.
        if(!objects.canFind!((ref o) => (result.pos - o.pos).length < result.radius + o.radius))
        {
            break;
        }
    }
    return result;
}

Entity createDebris(ref Entity parent, Entity[] objects)
{
    auto result = Entity(parent.debrisType);
    foreach(attempt; 0 .. 10)
    {
        result.rotRadians = uniform(0.0f, 2 * PI);
        const direction = result.rotRadians.directionVector;
        result.pos   = parent.pos + direction * (parent.radius + result.radius) * 1.5;
        result.speed = parent.speed + direction * uniform(30.0f, 90.0f);
        // If nothing collides with result, we have a good position.
        if(!objects.canFind!((ref o) => (result.pos - o.pos).length < result.radius + o.radius))
        {
            break;
        }
    }
    return result;
}


void main()
{
    writeln("Edit source/app.d to start your project.");


    auto log = new FileLogger("asteroids-log.txt", "Asteroids log");

    // Note: Many of the SDL init functions may fail and throw exceptions. In a real game,
    // this should be handled (e.g. a fallback renderer if accelerated doesn't work).
    auto platform = GamePlatform(log);

    import std.datetime: Clock;
    // Last time we checked FPS
    ulong prevFPSTime = Clock.currStdTime();
    // Number of frames since last FPS update
    uint frames = 0;


    // Time when the last frame started (in hectonanoseconds, or 10ths of a microsecond)
    ulong prevTime = prevFPSTime;
    auto game = new GameState();

    mainLoop: while(true)
    {
        const currTime = Clock.currStdTime();

        ++frames;

        const timeSinceFPS = currTime - prevFPSTime;
        game.frameTimeSecs  = (currTime - prevTime) / 10_000_000.0;
        prevTime = currTime;

        // Update FPS every 0.1 seconds/1000000 hectonanoseconds
        if(timeSinceFPS > 1_000_000)
        {
            const fps = frames / (timeSinceFPS / 10_000_000.0);
            platform.window.setTitle("Asteroids: %.2f FPS".format(fps));
            frames = 0;
            prevFPSTime = currTime;
        }

         // Shortcut for less typing
        alias T = Entity.Type;
        // This is pretty inefficient (recounting asteroids every frame).
        enum asteroidTypes = [T.AsteroidBig, T.AsteroidMed, T.AsteroidSmall];
        const asteroidCount = game.objects.count!((ref o) => asteroidTypes.canFind(o.type));

        // If there are no asteroids, start a new round by spawning some more.
        if(asteroidCount == 0)
        {
            ++game.round;
            // 2, 4, 8, 16 asteroids in rounds 1,2,3,4 but no more in successive rounds.
            foreach(spawn; 0 .. min(16, 2 ^^ game.round))
            {
                game.objects ~= createAsteroid(game.objects);
            }
        }
        entityMovement(game.objects, game.frameTimeSecs);

        if(!handleInput(game))
        {
            break;
        }

        entityCollisions(game.objects);
        game.objects = entityDeaths(game.objects, game.lives);

        // Game Over if the player has run out of lives.
        if(game.lives == 0)
        {
            game.phase = GameState.Phase.GameOver;
        }

        // Fill the entire screen with black (background) color.
        platform.renderer.setColor(0, 0, 0, 0);
        platform.renderer.clear();

        // Following draws will be white.
        platform.renderer.setColor(255, 255, 255, 255);
        entityRendering(game.objects, platform.renderer);

        // Draw player 'lives'
        foreach(life; 0 .. game.lives)
        {
            platform.renderer.renderObject(Entity.Type.Player,
                                        vec2f((1 + life) * 12.0f, 20.0f), 0.0f, 6.0f);
        }

        string text;
        final switch(game.phase)
        {
            case GameState.Phase.Playing:  text = "Round %s".format(game.round); break;
            case GameState.Phase.GameOver: text = "Game Over"; break;
        }

        // Extremely ineffecient way of displaying text
        // -- in a real project, this should be cached
        auto textSurface = platform.font.renderTextBlended(text, SDL_Color(255, 255, 255, 255));
        scope(exit) { textSurface.close(); }
        auto textTexture = new SDL2Texture(platform.renderer, textSurface);
        scope(exit) { textTexture.close(); }

        platform.renderer.copy(textTexture, (gameArea.x - textSurface.width) / 2, 16);

        // Show the drawn result on the screen (swap front/back buffers)
        platform.renderer.present();
    }
}
