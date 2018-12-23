// Mental state of the agent. 
enum State {
  Hungry,
  Media,
  Mating; 
};

class Agent {
  // Not evolving traits. 
  PVector position; PVector ahead; 
  PVector velocity; PVector acceleration;
  float wandertheta; 
  
  // Possible Genotypes.  
  float maxFoodPerceptionRad; float maxSeperationRad; float maxRadius; float maxMediaPerceptionRad; 
  float maxSpeed; float maxForce; float foodWeight; float seperationWeight; float mediaAttractionWeight; 
  float mediaAvoidanceWeight;
  float maxAheadDistance; // Lets us avoid media obstacles and get attracted to media bricks. 
  
  // Health units: Average of these determine the looming death of the agent. 
  // These could honestly evolve as well. This could be a genotype. 
  float bodyHealth; 
  float mediaHealth;
  
  // Current agent radius. 
  State curState;
  
  // DNA of the agent. 
  DNA dna;   
  
  // Init the agent. 
  Agent(PVector pos, DNA _dna) {
    position = pos;
    acceleration = new PVector(0, 0); 
    velocity = new PVector(random(-2,2), random(-2, 2));
    wandertheta = 0; 
    ahead = position.copy().add(velocity.copy().normalize().mult(maxAheadDistance));
    
    maxFoodPerceptionRad = agentVisionRadius; 
    maxMediaPerceptionRad = 100; 
    maxSpeed = 5.0;
    maxRadius = 8.0; // Size for the boid.
    maxSeperationRad = maxRadius*5;
    
    // TODO: Evolve these parameters. 
    maxForce = 0.1; foodWeight = 1.0; seperationWeight = 0.5; mediaAttractionWeight = 1.0; 
    mediaAvoidanceWeight = 0.5; 
    
    maxAheadDistance = 30.0;
    
    bodyHealth = 200.0; 
    mediaHealth = 200.0;
    
    curState = State.Hungry; 
    
    dna = _dna; 
  }
  
  void run(Food f) {
    // Update any GUI values
    maxFoodPerceptionRad = agentVisionRadius; 
    
    // Based on the current state, take actions. 
    behaviors(f);

    // Keep updating position until reaching the target.
    update(); 
    
    wraparound();
    display();
  }
  
  void behaviors(Food f) {
    PVector target;
    PVector steer; 
   
    // Determine the next action.
    switch (curState) {
      case Hungry: 
        // Steer torwards closest food.
        target = findFood(f);
        if (target != null) {
          steer = seek(target, true /*Arrive*/); 
          steer.mult(foodWeight); // Multiply by food weight. 
          applyForce(steer);
        }
       
        // Avoid any media obstacles. 
        steer = avoidMedia(f);
        steer.mult(mediaAvoidanceWeight);
        applyForce(steer);
        
        // Remove food from canvas if agent stepped on it. 
        consumeFood(f); 
        break; 
      
      case Media:
        target = findMedia(f); 
        if (target != null) {
         steer = seek(target, true);
         steer.mult(mediaAttractionWeight); 
         applyForce(steer);
        } else {
         // Wander around (Reset maxSpeed to get desired results)
         float oldMaxSpeed = maxSpeed; 
         maxSpeed = 2.0;
         steer = wander(); 
         steer.mult(0.1); // Wandering weight (can be constant) 
         applyForce(steer);
         maxSpeed = oldMaxSpeed; 
        }
        break; 
      
      default: 
        break;
    }
  }
  
  void applyForce(PVector force) {
    acceleration.add(force);  
  }

  // Update position
  void update() {
    // Update velocity
    velocity.add(acceleration);
    
    // Limit speed
    velocity.limit(maxSpeed);
    position.add(velocity);
    
    // Reset accelerationelertion to 0 each cycle
    acceleration.mult(0);
    
    // Update ahead vector position. 
    ahead = position.copy().add(velocity.copy().normalize().mult(maxAheadDistance));
    
    // Death always looming
    bodyHealth -= 0.1;
  }
  
  // -------------------------------------------- Steering Behaviors -------------------------------------------
  
  PVector wander() {
    float wanderR = 20;         // Radius for our "wander circle"
    float wanderD = 60;         // Distance for our "wander circle"
    float change = 0.1;
    wandertheta += random(-change,change);     // Randomly change wander theta

    // Now we have to calculate the new position to steer towards on the wander circle
    PVector circlepos = velocity.get();    // Start with velocity
    circlepos.normalize();            // Normalize to get heading
    circlepos.mult(wanderD);          // Multiply by distance
    circlepos.add(position);               // Make it relative to boid's position

    float h = velocity.heading2D();        // We need to know the heading to offset wandertheta

    PVector circleOffSet = new PVector(wanderR*cos(wandertheta+h),wanderR*sin(wandertheta+h));
    PVector target = PVector.add(circlepos,circleOffSet);
    
    // Render wandering circle, etc.
    //drawWanderStuff(position,circlepos,target,wanderR);
    return seek(target);
  }
  // Calculates a steering force towards a target. 
  // STEER = DESIRED MINUS VELOCITY
  PVector seek(PVector target) {
     return seek(target, false); 
  }
  
  PVector seek(PVector target, boolean arrive) {
    PVector desired = PVector.sub(target,position);  // A vector pointing from the position to the target
    
    // Slow down when coming towards the target
    if (arrive) {
       float d = desired.mag(); 
       if (d < 100) {
          float m = map(d, 0, 100, 0, maxSpeed);
          desired.setMag(m);
       } else {
          desired.setMag(maxSpeed); 
       }
    } else {
      // Normalize desired and scale to maximum speed
      desired.normalize();
      desired.mult(maxSpeed);
    }
    
    // Steering = Desired minus Velocity
    PVector steer = PVector.sub(desired,velocity);
    steer.limit(maxForce);  // Limit to maximum steering force
    
    return steer; 
  }
  
  // Obstacle avoidance. 
  PVector avoidMedia(Food f) {
    PVector steer = new PVector(0, 0);
    for (PixelBrick pb : f.bricks) {
      float desiredSeperation = pb.getCircleRad() + maxRadius;
      
      if (PVector.dist(ahead, pb.center) < desiredSeperation) {
        // Obstacle ahead. Steer to avoid this obstacle. 
        PVector desired = PVector.sub(ahead, pb.center); 
        desired.normalize(); 
        desired.limit(maxSpeed); 
        steer = PVector.sub(desired, velocity); 
        steer.limit(maxForce); 
      }
    }
    return steer; 
  }
 
  
  // Checks for nearby boids and steers away. 
  void seperation(ArrayList<Agent> agents) {
    PVector sum = new PVector();
    int count = 0;
    // For every boid in the system, check if it's too close
    for (Agent other : agents) {
      float d = PVector.dist(position, other.position);
      // If the distance is greater than 0 and less than desired distance. 
      if ((d > 0) && (d < maxSeperationRad)) {
        // Calculate vector pointing away from neighbor
        PVector diff = PVector.sub(position, other.position);
        diff.normalize();
        diff.div(d);
        sum.add(diff);
        count++;
      }
    }
    
    if (count > 0) {
      sum.setMag(maxSpeed);
      PVector steer = PVector.sub(sum, velocity);
      steer.limit(maxForce);
      steer.mult(seperationWeight);
      applyForce(steer);
    }
  }
  
  PVector findFood(Food f) {
    float minD = 5000000; // Helpful to calculate a local minima. 
    PVector target = null;
    
    // Find the closest food particle.
    for (Flower fl : f.flowers) {
       PVector center = new PVector(fl.position.x + fl.flowerWidth/2, fl.position.y + fl.flowerHeight/2);
       // Calculate the minimum distance to food
       float d = PVector.dist(position, center); 
       if (d < maxFoodPerceptionRad) {
         if (d < minD) {
           minD = d;   
           target = center; 
         }
       }
    }
    
    return target; 
  }
  
  PVector findMedia(Food f) {
    float minD = 5000000; // Helpful to calculate a local minima. 
    PVector target=null;
    
    for (PixelBrick pb : f.bricks) {
     // Find the closest food particle.
     // Calculate the minimum distance to food
     float d = PVector.dist(position, pb.center); 
     if (d < maxMediaPerceptionRad) {
       if (d < minD) {
         minD = d;   
         target = pb.center; 
       }
     }
    }
    
    return target; 
  }
  
  // Did it just step on food when it was hungry? 
  void consumeFood(Food f) {
    ArrayList<Flower> flowers = f.flowers;
    // Are we touching any food objects?
    for (int i = flowers.size()-1; i >= 0; i--) {
      Flower fl = flowers.get(i);
      float flWidth = fl.flowerWidth; float flHeight = fl.flowerHeight; 
      PVector center = new PVector(fl.position.x + flWidth/2, fl.position.y + flHeight/2);
      float d = PVector.dist(position, center); // Distance between agent's position and flower's center.
      if (d < maxRadius) {
        bodyHealth += 100; 
        flowers.remove(i);
        
        // 30% chance a new flower is created after its eaten. 
        if (random(1) < 0.95) {
         f.createFlowers(1); 
        } 
      }
    }
  }
  
  void display() {
    pushMatrix();
     pushStyle();
      // Draw a boid.  
      float theta = velocity.heading() + radians(90);
      translate(position.x,position.y);
      rotate(theta);
      fill(255);
      stroke(0, bodyHealth);
      beginShape(TRIANGLES);
      vertex(0, -maxRadius*2);
      vertex(-maxRadius, maxRadius*2);
      vertex(maxRadius, maxRadius*2);
      endShape();
     popStyle();
    popMatrix();
    
    // Debug content. 
    displayDebug();
  }
  
  void displayDebug() {
    // Debug content
    if (debug) {
      pushStyle();
      stroke(255);
      strokeWeight(3);
      line(position.x, position.y, ahead.x, ahead.y);
      popStyle();
     
      // Position marker. 
      fill(0, 255, 0);
      ellipse(position.x, position.y, 3, 3);
    }
    
    // Vision circle.
    if (turnOnVision) {
      // Food perception radius.
      fill(color(0, 255, 0, 50));
      ellipse(position.x,position.y,maxFoodPerceptionRad, maxFoodPerceptionRad); 
      
      // Seperation radius
      fill(color(255, 0, 0, 50));
      ellipse(position.x,position.y,maxSeperationRad,maxSeperationRad); 
      
      // Media perception radius. 
      fill(color(255, 255, 0, 50)); 
      ellipse(position.x, position.y, maxMediaPerceptionRad, maxMediaPerceptionRad);
    }
  }
  
  // A method just to draw the circle associated with wandering
  void drawWanderStuff(PVector position, PVector circle, PVector target, float rad) {
    stroke(255);
    noFill();
    ellipseMode(CENTER);
    ellipse(circle.x,circle.y,rad*2,rad*2);
    ellipse(target.x,target.y,4,4);
    line(position.x,position.y,circle.x,circle.y);
    line(circle.x,circle.y,target.x,target.y);
  }
  
  // At any moment there is a teeny, tiny chance a bloop will reproduce
  Agent reproduce() {
    // asexual reproduction
    if (random(1) < 0.001) {
      // Child is exact copy of this single parent. 
      DNA childDNA = dna.copy();
      // Child DNA can mutate
      childDNA.mutate(0.01);
      // Child is exact copy of single parent
      return new Agent(new PVector(random(width), random(height)), childDNA);
    } 
    else {
      return null;
    }
  }
  
  void wraparound() {
    if (position.x < -maxRadius) position.x = width+maxRadius;
    if (position.y < -maxRadius) position.y = height+maxRadius;
    if (position.x > width+maxRadius) position.x = -maxRadius;
    if (position.y > height+maxRadius) position.y = -maxRadius;
  }
  
  // Check for death
  boolean dead() {
    if (bodyHealth < 0.0) {
      return true;
    } 
    else {
      return false;
    }
  }
};
