============================================
Setting up (D compiler, DUB, SDL2, SDL2-TTF)
============================================


----------
D compiler
----------

D 'language version' depends on the version of the compiler frontend, which is shared by
DMD, GDC and LDC. For example, the newest frontend version is ``2.066``. LDC and GDC are
usually about a month behind DMD (e.g. current stable LDC is ``2.065`` but LDC beta is
``2.066``).

DMD is not present in any official repos because its backend's license is not OSS.

^^^^^^^^^^^^^^^^^^
Debian/*buntu/Mint
^^^^^^^^^^^^^^^^^^

* **Debian stable** has a very old version of GDC. Not recommended.
* **Debian unstable** (and **testing**?) as well as **\*buntu 14.10** have up-to-date 
  versions of GDC. Not certain about **Ubuntu 14.04**/**Mint 17**.

^^^^^^
Fedora
^^^^^^

* Fedora 20/21 have an extremely ancient version of LDC in their repos.

  See *All distros/platforms* below to get an up-to-date version.

^^^^
Arch
^^^^

* You probably have the newest versions of everything but I can't help you.


^^^^^^^^^^^^^^^^^^^^^
All distros/platforms
^^^^^^^^^^^^^^^^^^^^^

Official/current binaries (Linux, Windows, OSX, etc.) for `GDC
<http://gdcproject.org/downloads>`_, `LDC
<https://github.com/ldc-developers/ldc/releases>`_ and `DMD
<http://dlang.org/download.html>`_


---
DUB
---

Official binaries `here <http://code.dlang.org/download>`_.



--------------
SDL2, SDL2-TTF
--------------

* Debuntu: ``sudo apt-get install libsdl2-dev libsdl2-ttf-dev``
* Fedora: ``yum install SDL2-devel SDL2_ttf-devel`` ?
