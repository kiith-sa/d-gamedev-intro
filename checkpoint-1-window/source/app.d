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


void main()
{
    writeln("Edit source/app.d to start your project.");


    auto log = new FileLogger("asteroids-log.txt", "Asteroids log");

    // Note: Many of the SDL init functions may fail and throw exceptions. In a real game,
    // this should be handled (e.g. a fallback renderer if accelerated doesn't work).
    auto platform = GamePlatform(log);

    mainLoop: while(true)
    {
        SDL_Event event;
        while(SDL_PollEvent(&event))
        {
            if(event.type == SDL_QUIT) { break mainLoop; }
        }

        // Fill the entire screen with black (background) color.
        platform.renderer.setColor(0, 0, 0, 0);
        platform.renderer.clear();

        // Show the drawn result on the screen (swap front/back buffers)
        platform.renderer.present();
    }
}
