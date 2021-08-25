Agent-Based Model developped in the [CityScience](https://www.media.mit.edu/groups/city-science/overview/) group using [Gama Platform](https://gama-platform.github.io/) and integrated in [CityScope](https://www.media.mit.edu/projects/cityscope/overview/)

# Installation
  - Clone this reposetory
  - Download GAMA (compatible with GAMA 1.8.1) [here](https://gama-platform.github.io/download)
  - Run GAMA, 
  - Choose a new Workspace (this is a temporay folder used for computation)
  - right click on User Models->Import->GAMA Project..
  - Select CS_CityScope_GAMA in the CS_Simulation_GAMA folder that you have clone

# Overall Structure:
- The `parameters.gama` file specificies universal constants and simulation parameters
- The `Agents.gama` file specifies simulation species and their behaviors.
- The `clustering.gama` file specifies the initialization state, as well as the different experiments to be run and a few global functions
