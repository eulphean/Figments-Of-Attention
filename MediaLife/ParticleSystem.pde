class Particle {
 PVector position;
 PVector velocity;
 color particleColor; 
 PShape particle; 
 
 
 Particle() { 
   ellipseMode(CENTER); 
   particle = createShape(ELLIPSE, 0, 0, 4, 4);
 }
 
 void run(float alpha) {
   position = position.add(velocity); 
   particleColor = (particleColor & 0xffffff) | (floor(alpha) << 24); 
   pushStyle();
   noStroke();
   pushMatrix();
     translate(position.x, position.y); 
     particle.setFill(particleColor); 
     particle.setStroke(particleColor);
     shape(particle);
   popMatrix();
   //ellipse(position.x, position.y, 4, 4); 
   popStyle();
 }
 
 void init(PVector newPos, color c) {
   position = new PVector(0, 0);
   position.x = newPos.x;
   position.y  = newPos.y;
   velocity = new PVector(random(-1, 1), random(-1, 1)); 
   particleColor = color(random(255), random(255), random(255));

 }
}

class ParticleSystem {
  ArrayList<Particle> particles; 
  int numParticles;
  boolean run; float alpha; int frame; int maxFrames; 
  color particleColor;
  
  ParticleSystem() {
   numParticles = 25;
   run = false; 
   alpha = 255; frame = 0; maxFrames = 100; 
   particles = new ArrayList(); 
   for (int i = 0; i < numParticles; i++) {
     particles.add(new Particle()); 
   }
  }
  
  void run() {
   alpha = map(frame, 0, maxFrames, 255, 0);
   if (run) {
     for (Particle p: particles) {
       p.run(alpha);
     }
     frame++;
   }
     
   // Stop the particle system until it's reset. 
   if (frame == maxFrames) {
    run = false; 
   }
  }
  
  void init(PVector position, color particleColor) {
    // Initialize the system. 
    alpha = 255; frame = 0;  
    for (int i = 0; i < numParticles; i++) {
     particles.get(i).init(position, particleColor); 
    }
    
    // Run it. 
    run = true; 
  }
  
}
