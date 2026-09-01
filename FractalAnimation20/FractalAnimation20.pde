// Cosmic Swirl — Fractal Overlay Edition
// The swirl animation runs continuously, never stopping. At random
// intervals of 5-10s, one fractal image appears on top of it at a
// random position, sized to 75% of the screen area, fading in, then
// gently twisting, turning, and bending/warping like cloth while
// it's shown, then fading out again before it vanishes (5s total).
// The animation is unaffected throughout.
//
// The image folder is watched while the sketch runs (see
// RESCAN_INTERVAL_FRAMES below): just drop new images into
// fractalFolder, or delete ones you don't want any more, and the
// gallery picks up the change automatically — no restart needed.

// ------------------------------------------------------------------
// CONFIG — edit these two lines for your machine
// ------------------------------------------------------------------
// Point this at the folder of fractal images to show on the display.
// Examples:
//   Raspberry Pi: "/home/pi/Pictures/fractals"
//   Windows (OneDrive syncs to a real folder on disk; "OneDrive -
//     Personal" is how it appears in Explorer, not the actual path):
//     "C:/Users/<you>/OneDrive/Art/Fractals/Video"
//   Mac:          "/Users/<you>/OneDrive/Art/Fractals/Video"

String fractalFolder = "/home/pi/Pictures/fractals";

// Matches any file starting with this (case-insensitive), so
// "Fractal- 1.jpg", "Fractal-12.png" etc. all match.
String fileNamePrefix = "fractal";

import java.util.Collections;

float noiseScale = 0.005;
float time = 0;
float colorOffset;
float pulse;
float camDrift;
int harmonyMode = 0;
float gravitySign = 1;
ArrayList<Particle> particles;
ArrayList<Shockwave> shockwaves;

// ---- Autonomous "virtual mouse" ----
float autoMouseX, autoMouseY;
float mouseTargetX, mouseTargetY;
float mouseWanderT = 0;
float mouseSpeed;

// ---- Autonomous event timers ----
int nextShockwaveFrame;
int nextMutateFrame;

// ---- Fractal image gallery ----
ArrayList<String> imagePaths;
ArrayList<String> shuffleBag;
String lastShownPath = null;
PImage currentImg;

// ---- Live folder watching ----
int nextRescanFrame;
final int RESCAN_INTERVAL_FRAMES = 600; // check the folder every 10s at 60fps

// ---- Fractal overlay state ----
boolean showingImage = false;
int imageShowStartFrame;
int nextImageFrame;
final int IMAGE_SHOW_FRAMES = 300;   // 5s at 60fps
final int IMAGE_FADE_FRAMES = 45;    // 0.75s fade in, 0.75s fade out
final float IMAGE_AREA_FRACTION = 0.75; // 75% of screen area
float imgX, imgY, imgW, imgH;

// Twist/turn — randomised fresh for every appearance
float rotAmplitude, rotSpeed, rotPhase;
float turnAmplitude, turnSpeed, turnPhase;

// Bend/warp mesh — the image is drawn as a grid of textured triangles
// whose vertices ripple over time, so it bends like cloth rather than
// just rotating/squashing as a rigid rectangle. Randomised fresh for
// every appearance, same as the twist/turn parameters above.
final int WARP_COLS = 22;
final int WARP_ROWS = 16;
float warpAmpX, warpAmpY;
float warpFreqX, warpFreqY;
float warpSpeedX, warpSpeedY;
float warpPhaseX, warpPhaseY;

void setup() {
  size(1920, 1080, P2D);
  frameRate(60);
  background(10);
  colorMode(HSB, 360, 100, 100, 100);

  loadFractalFileList();
  shuffleBag = new ArrayList<String>();
  nextRescanFrame = frameCount + RESCAN_INTERVAL_FRAMES;

  particles = new ArrayList<Particle>();
  for (int i = 0; i < 850; i++) {
    particles.add(new Particle());
  }
  shockwaves = new ArrayList<Shockwave>();

  autoMouseX = width / 2;
  autoMouseY = height / 2;
  mouseTargetX = autoMouseX;
  mouseTargetY = autoMouseY;
  mouseWanderT = random(1000);
  mouseSpeed = random(0.02, 0.05);

  // Overlay is sized to cover IMAGE_AREA_FRACTION of the screen
  // while keeping the image's own aspect ratio (matches the canvas
  // here, so this is just scaling both dimensions equally).
  float scaleFactor = sqrt(IMAGE_AREA_FRACTION);
  imgW = width * scaleFactor;
  imgH = height * scaleFactor;

  scheduleNextShockwave();
  scheduleNextMutate();
  scheduleNextImage();
  mutate();
}

void draw() {
  runAnimationFrame();

  if (frameCount >= nextRescanFrame) {
    rescanFractalFileList();
    nextRescanFrame = frameCount + RESCAN_INTERVAL_FRAMES;
  }

  if (!showingImage && !imagePaths.isEmpty() && frameCount >= nextImageFrame) {
    currentImg = loadImage(nextImagePath());
    imgX = random(0, width - imgW);
    imgY = random(0, height - imgH);
    showingImage = true;
    imageShowStartFrame = frameCount;

    rotAmplitude = random(0.15, 0.35);
    rotSpeed = random(0.5, 1.2);
    rotPhase = random(TWO_PI);
    turnAmplitude = random(0.15, 0.4);
    turnSpeed = random(0.4, 1.0);
    turnPhase = random(TWO_PI);

    warpAmpX = random(0.02, 0.05) * imgW;
    warpAmpY = random(0.02, 0.05) * imgH;
    warpFreqX = random(1.5, 3.5);
    warpFreqY = random(1.5, 3.5);
    warpSpeedX = random(0.5, 1.3);
    warpSpeedY = random(0.5, 1.3);
    warpPhaseX = random(TWO_PI);
    warpPhaseY = random(TWO_PI);
  }

  if (showingImage) {
    drawImageOverlay();
    if (frameCount - imageShowStartFrame >= IMAGE_SHOW_FRAMES) {
      showingImage = false;
      scheduleNextImage();
    }
  }
}

void drawImageOverlay() {
  if (currentImg == null) return;
  int elapsed = frameCount - imageShowStartFrame;
  float fadeAlpha;
  if (elapsed < IMAGE_FADE_FRAMES) {
    fadeAlpha = map(elapsed, 0, IMAGE_FADE_FRAMES, 0, 255);
  } else if (elapsed > IMAGE_SHOW_FRAMES - IMAGE_FADE_FRAMES) {
    fadeAlpha = map(elapsed, IMAGE_SHOW_FRAMES - IMAGE_FADE_FRAMES, IMAGE_SHOW_FRAMES, 255, 0);
  } else {
    fadeAlpha = 255;
  }
  fadeAlpha = constrain(fadeAlpha, 0, 255);

  float t = elapsed / 60.0;
  // Twist: a gentle rocking rotation, never a full spin
  float angle = sin(t * rotSpeed + rotPhase) * rotAmplitude;
  // Turn: squashes horizontally to suggest the image turning in space,
  // like a card rocking on its vertical axis
  float turnScale = 1.0 - turnAmplitude * (0.5 + 0.5 * sin(t * turnSpeed + turnPhase));

  pushStyle();
  pushMatrix();
  translate(imgX + imgW / 2, imgY + imgH / 2);
  rotate(angle);
  scale(turnScale, 1);

  noStroke();
  fill(0, 0, 0, 40 * (fadeAlpha / 255.0));
  rect(-imgW / 2 + 6, -imgH / 2 + 6, imgW, imgH);

  drawWarpedImage(currentImg, imgW, imgH, fadeAlpha, t);

  popMatrix();
  popStyle();
}

// Draws the image as a grid of textured triangles, displacing each
// vertex with layered sine waves so the whole picture bends and
// ripples like cloth in a breeze while it's on screen, instead of
// staying a rigid rectangle under the outer rotate/scale.
void drawWarpedImage(PImage img, float w, float h, float alpha, float t) {
  tint(255, alpha);
  textureMode(NORMAL);
  noStroke();
  for (int row = 0; row < WARP_ROWS; row++) {
    beginShape(TRIANGLE_STRIP);
    texture(img);
    for (int col = 0; col <= WARP_COLS; col++) {
      float u = col / (float) WARP_COLS;
      float v0 = row / (float) WARP_ROWS;
      float v1 = (row + 1) / (float) WARP_ROWS;
      PVector p0 = warpPoint(u, v0, w, h, t);
      PVector p1 = warpPoint(u, v1, w, h, t);
      vertex(p0.x, p0.y, u, v0);
      vertex(p1.x, p1.y, u, v1);
    }
    endShape();
  }
  noTint();
}

// Maps a point on the flat image (u, v in [0,1]) to its bent local
// position. Two sine terms per axis — one keyed off the other axis's
// coordinate, one off its own — give an organic bend rather than a
// simple uniform wave.
PVector warpPoint(float u, float v, float w, float h, float t) {
  float px = (u - 0.5) * w;
  float py = (v - 0.5) * h;

  float bendX = sin(v * warpFreqY + t * warpSpeedY + warpPhaseY) * warpAmpX
    + sin(u * warpFreqX * 0.5 + t * warpSpeedX * 0.7 + warpPhaseX) * warpAmpX * 0.4;
  float bendY = sin(u * warpFreqX + t * warpSpeedX + warpPhaseX) * warpAmpY
    + sin(v * warpFreqY * 0.5 + t * warpSpeedY * 0.7 + warpPhaseY) * warpAmpY * 0.4;

  return new PVector(px + bendX, py + bendY);
}

void runAnimationFrame() {
  updateAutoMouse();
  maybeFireAutoEvents();

  camDrift += 0.00045;
  translate(width/2, height/2);
  rotate(sin(camDrift * 0.6) * 0.06);
  translate(-width/2, -height/2);
  translate(sin(camDrift) * 18, cos(camDrift * 1.3) * 18);

  fill(10, 14);
  noStroke();
  rect(-150, -150, width + 300, height + 300);
  pulse = sin(time * 1.4) * 0.45 + 1.25;

  noFill();
  strokeWeight(1.3);
  for (int x = 40; x < width - 40; x += 48) {
    for (int y = 40; y < height - 40; y += 48) {
      float dToMouse = dist(x, y, autoMouseX, autoMouseY);
      float mouseInfluence = map(min(dToMouse, 280), 0, 280, TWO_PI * gravitySign, 0);
      float angle = noise(x * noiseScale, y * noiseScale, time) * TWO_PI * 3.2;
      angle += mouseInfluence;

      float len = noise(y * noiseScale, x * noiseScale, time * 0.28) * 60 * pulse;
      for (Shockwave sw : shockwaves) {
        float d = dist(x, y, sw.pos.x, sw.pos.y);
        float ringDist = abs(d - sw.radius);
        if (ringDist < sw.thickness) {
          float warp = map(ringDist, 0, sw.thickness, 1, 0) * sw.strength;
          angle += atan2(y - sw.pos.y, x - sw.pos.x) * 0.15 * warp;
          len += warp * 40;
        }
      }

      float hue;
      if (harmonyMode == 0) {
        hue = (colorOffset + angle * 22 + time * 12) % 360;
      } else if (harmonyMode == 1) {
        hue = (colorOffset + dToMouse * 0.25) % 360;
      } else {
        hue = (colorOffset + (angle > PI ? 180 : 0) + time * 6) % 360;
      }
      float sat = map(sin(time + x * 0.01), -1, 1, 70, 100);
      float bri = map(cos(time + y * 0.01), -1, 1, 45, 95);
      stroke(hue, sat, bri, 28);

      pushMatrix();
      translate(x, y);
      rotate(angle);
      beginShape();
      vertex(-len/2, 0);
      bezierVertex(-len/4, sin(time * 0.8) * 14, len/4, -sin(time * 0.8) * 14, len/2, 0);
      endShape();
      popMatrix();
    }
  }

  for (int i = shockwaves.size() - 1; i >= 0; i--) {
    Shockwave sw = shockwaves.get(i);
    sw.update();
    sw.show();
    if (sw.isDead()) shockwaves.remove(i);
  }

  for (Particle p : particles) {
    p.update();
    p.show();
  }

  time += 0.0032;
}

// --------------------------------------------------------------
// Fractal image gallery
// --------------------------------------------------------------
void loadFractalFileList() {
  imagePaths = scanFractalFolder();
  if (imagePaths.isEmpty()) {
    println("No fractal images found in: " + fractalFolder);
    println("Check the fractalFolder path and fileNamePrefix at the top of the sketch.");
  } else {
    println("Loaded " + imagePaths.size() + " fractal image(s).");
  }
}

// Re-reads the folder and, if anything changed, swaps in the fresh
// list. Any images already queued in the shuffle bag that have since
// been deleted are dropped from the queue; newly added images join
// the gallery the next time the bag is reshuffled. This is what lets
// images be added or deleted from fractalFolder while the sketch is
// running, with no restart required.
void rescanFractalFileList() {
  ArrayList<String> fresh = scanFractalFolder();
  if (fresh.equals(imagePaths)) return;

  imagePaths = fresh;
  if (shuffleBag != null) shuffleBag.retainAll(imagePaths);
  println("Fractal folder changed — now " + imagePaths.size() + " image(s).");
}

ArrayList<String> scanFractalFolder() {
  File folder = new File(fractalFolder);
  String[] names = folder.list();
  ArrayList<String> matches = new ArrayList<String>();
  if (names != null) {
    for (String n : names) {
      String lower = n.toLowerCase();
      boolean isImage = lower.endsWith(".jpg") || lower.endsWith(".jpeg")
        || lower.endsWith(".png") || lower.endsWith(".tif") || lower.endsWith(".tiff");
      if (isImage && lower.startsWith(fileNamePrefix)) {
        matches.add(fractalFolder + "/" + n);
      }
    }
  }
  Collections.sort(matches);
  return matches;
}

// Draws from a shuffled bag so every image is shown once before any
// repeat, then reshuffles — a fair random sequence rather than a
// naive random pick that can repeat the same image back to back.
String nextImagePath() {
  if (shuffleBag == null || shuffleBag.isEmpty()) {
    shuffleBag = new ArrayList<String>(imagePaths);
    Collections.shuffle(shuffleBag);
    if (imagePaths.size() > 1 && shuffleBag.get(shuffleBag.size() - 1).equals(lastShownPath)) {
      Collections.swap(shuffleBag, 0, shuffleBag.size() - 1);
    }
  }
  String path = shuffleBag.remove(shuffleBag.size() - 1);
  lastShownPath = path;
  return path;
}

void scheduleNextImage() {
  // Random 5-10s at 60fps, counted from when the overlay disappears
  nextImageFrame = frameCount + int(random(5, 10) * 60);
}

// --------------------------------------------------------------
// Autonomous "virtual mouse" — smooth random wandering
// --------------------------------------------------------------
void updateAutoMouse() {
  mouseWanderT += mouseSpeed;
  if (frameCount % 90 == 0) {
    mouseTargetX = random(80, width - 80);
    mouseTargetY = random(80, height - 80);
    mouseSpeed = random(0.015, 0.05);
  }
  float wanderX = map(noise(mouseWanderT, 0), 0, 1, -160, 160);
  float wanderY = map(noise(0, mouseWanderT), 0, 1, -160, 160);
  autoMouseX = lerp(autoMouseX, mouseTargetX + wanderX, 0.03);
  autoMouseY = lerp(autoMouseY, mouseTargetY + wanderY, 0.03);
  autoMouseX = constrain(autoMouseX, 0, width);
  autoMouseY = constrain(autoMouseY, 0, height);
}

// --------------------------------------------------------------
// Autonomous event scheduling
// --------------------------------------------------------------
void maybeFireAutoEvents() {
  if (frameCount >= nextShockwaveFrame) {
    shockwaves.add(new Shockwave(autoMouseX, autoMouseY));
    scheduleNextShockwave();
  }
  if (frameCount >= nextMutateFrame) {
    mutate();
    scheduleNextMutate();
  }
}

void scheduleNextShockwave() {
  nextShockwaveFrame = frameCount + int(random(90, 270));
}

void scheduleNextMutate() {
  nextMutateFrame = frameCount + int(random(480, 1200));
}

void mutate() {
  noiseScale = random(0.003, 0.009);
  colorOffset = random(360);
  camDrift = random(5000);
  harmonyMode = int(random(3));
  gravitySign = random(1) > 0.5 ? 1.0 : -1.0;
  background(10);
  particles.clear();
  for (int i = 0; i < 850; i++) {
    particles.add(new Particle());
  }
}

// --------------------------------------------------------------
// Shockwave Class — Expanding gravitational ring
// --------------------------------------------------------------
class Shockwave {
  PVector pos;
  float radius;
  float maxRadius;
  float speed;
  float thickness;
  float strength;
  float hue;
  boolean attract;

  Shockwave(float x, float y) {
    pos = new PVector(x, y);
    radius = 0;
    maxRadius = max(width, height) * 0.9;
    speed = random(6, 9);
    thickness = 60;
    strength = 3.2;
    hue = (colorOffset + random(-40, 40) + 360) % 360;
    attract = random(1) > 0.5;
  }

  void update() {
    radius += speed;
    thickness = max(20, thickness * 0.995);
    strength *= 0.985;
  }

  boolean isDead() {
    return radius > maxRadius || strength < 0.05;
  }

  void show() {
    float alpha = map(strength, 0, 3.2, 0, 70);
    noFill();
    for (int i = 0; i < 3; i++) {
      float rOffset = i * 6;
      stroke((hue + i * 20) % 360, 85, 100, alpha * (1 - i * 0.3));
      strokeWeight(2 - i * 0.5);
      ellipse(pos.x, pos.y, (radius + rOffset) * 2, (radius + rOffset) * 2);
    }
  }

  PVector forceOn(PVector p) {
    float d = PVector.dist(p, pos);
    float ringDist = abs(d - radius);
    if (ringDist > thickness || strength < 0.05) {
      return new PVector(0, 0);
    }
    float mag = map(ringDist, 0, thickness, strength, 0);
    PVector dir = PVector.sub(p, pos);
    if (dir.mag() < 0.001) dir = new PVector(random(-1, 1), random(-1, 1));
    dir.normalize();
    if (attract) dir.mult(-1);
    dir.mult(mag);
    return dir;
  }
}

// --------------------------------------------------------------
// Particle Class — Ribbon Trails + Micro-Turbulence
// --------------------------------------------------------------
class Particle {
  PVector pos, vel;
  ArrayList<PVector> history;
  int maxTrail = 10;
  float sizeSize;
  float speedLimit;

  Particle() {
    pos = new PVector(random(width), random(height));
    vel = new PVector(0, 0);
    history = new ArrayList<PVector>();
    sizeSize = random(1.5, 4.8);
    speedLimit = random(2.2, 4.8);
  }

  void update() {
    history.add(pos.copy());
    if (history.size() > maxTrail) history.remove(0);
    float angle = noise(pos.x * noiseScale, pos.y * noiseScale, time) * TWO_PI * 3.2;
    angle += sin(time * 0.7 + pos.x * 0.01) * 0.15;
    angle += cos(time * 0.6 + pos.y * 0.01) * 0.15;
    PVector force = new PVector(cos(angle), sin(angle));

    PVector mouseVec = new PVector(autoMouseX, autoMouseY);
    float d = PVector.dist(pos, mouseVec);
    if (d < 260) {
      PVector steer = PVector.sub(mouseVec, pos);
      steer.normalize();
      steer.mult(map(d, 0, 260, 1.3, 0) * gravitySign);
      force.add(steer);
    }

    for (Shockwave sw : shockwaves) {
      force.add(sw.forceOn(pos));
    }

    vel.add(force.mult(0.42));
    vel.limit(speedLimit);
    pos.add(vel);

    if (pos.x < 0 || pos.x > width || pos.y < 0 || pos.y > height) {
      pos.set(random(width), random(height));
      history.clear();
    }
  }

  void show() {
    if (history.size() < 2) return;
    for (int i = 0; i < history.size() - 1; i++) {
      PVector a = history.get(i);
      PVector b = history.get(i + 1);
      float progress = (float)i / history.size();
      float hue = (colorOffset + progress * 45 + pos.x * 0.12) % 360;
      strokeWeight(sizeSize * progress);
      stroke(hue, 85, 100, progress * 50);
      line(a.x, a.y, b.x, b.y);
    }
  }
}
