def utils
pipeline{
    agent any 
    environment{
        // Boutique Source
        SRC_SCM_BRANCH = "release/v0.10.2" // like; "release/v0.10.2"
    }
    stages{
        stage("init"){ 
            steps{  
                script{
                    echo "init" 
                    utils = load "utils.groovy"
                }
            } 
        }

        stage("Download Source"){ 
            steps{
                script{
                    echo "Download Souce" 
                    utils.downloadSource($SRC_SCM_BRANCH)
                }
            } 
        } // If downloaded before, just git pull





        stage("Build Images"){ steps{  echo "Build Images" } } //CVE check, too
        stage("Push Images"){ steps{  echo "Push Images" } }
        // create helm and plan manifest from helm template

    }
}