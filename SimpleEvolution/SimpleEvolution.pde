int numAgents = 20; int numFood = numAgents; // Starting parameters for food. 

// Initialize a world
World world;

void setup() {
  size(200, 200);
  
  world = new World(numAgents);
  ellipseMode(RADIUS);
  smooth();
}

void draw() {
  background(255);
    
  // Update environment
  world.run();
}