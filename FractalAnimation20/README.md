# FractalAnimation20 — Cosmic Swirl display

A Processing sketch for the Pi display: a swirling particle animation
that runs forever, with fractal images from a folder fading in on top
of it every 5-10s.

## Setup

1. Install [Processing](https://processing.org/download) (the same
   IDE works on the Pi, or run it headless with the `processing-java`
   command line tool).
2. Open `FractalAnimation20.pde`.
3. Edit the two lines at the top of the file:
   - `fractalFolder` — the folder holding your fractal images, e.g.
     `/home/pi/Pictures/fractals` on the Pi.
   - `fileNamePrefix` — files must start with this (case-insensitive)
     to be picked up, e.g. `fractal` matches `Fractal-1.jpg`,
     `fractal_02.png`, etc.
4. Run the sketch, then switch it to fullscreen/Present mode so it
   fills the display.

## Adding or removing images

Nothing needs restarting: drop new images into `fractalFolder`, or
delete ones you no longer want, and the sketch notices within about
10 seconds (it re-checks the folder in the background) and updates
the gallery it draws from — new files join the rotation, deleted
files stop appearing. An image already fading in/out on screen when
it's deleted keeps finishing its current appearance, since it's
already loaded into memory.

## Running full-screen on boot (Raspberry Pi)

1. Export the sketch as an application from Processing
   (`File > Export Application`, choosing Linux), or install
   `processing-java` and run the sketch from its `.pde` folder with:
   ```
   processing-java --sketch=/path/to/FractalAnimation20 --present --run
   ```
2. Add that command to autostart so it launches on boot, e.g. via
   `/etc/xdg/lxsession/LXDE-pi/autostart` (Raspbian desktop) or a
   `systemd` service if running headless with a framebuffer.
3. See the top-level `Display Screen` notes in this repo for the
   HDMI/overscan settings this particular 7" display needed to work
   on the Pi.
