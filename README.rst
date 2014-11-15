========================
Intro to gamedev using D
========================

This is a tutorial about writing a simple game in D. The tutorial is a `bunch of HTML
slides <http://defenestrate.eu/_static/ossvikend/intro-gamedev-d/slides/index.html#>`_ but
it supposed to be used directly for copy-pasting code instead of being used as
a presentation. The focus is on making a game (for non-game developers) as opposed on
learning D itself, so the code is somewhat C-like.

This repository also contains code that should be the final result of the tutorial (a
simple *Asteroids* clone), as well as a bunch of "checkpoints" containing work-in-progress
code (useful for live workshops).

Directory structure:

======================= ===================================================
slides/source           Slides source code (ReStructuredText)
slides/build/slides     Generated HTML slides
source                  Final source code
checkpoint-*            Source code "checkpoints"
asteroids.png           Screenshot of the final game
asteroids.webm          Video of the final game
DroidSans*              Game font and related files
dub.json                DUB (package manager/build system) config file
screens                 Screens of a VM used this workshop
setting_up.rst          Setting up environment for this workshop
LICENSE_1_0.txt         Boost license
README.rst              This README
======================= ===================================================
