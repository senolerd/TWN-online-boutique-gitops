def utils
pipeline{
    agent any 
    environment{
        // Boutique Source
        BOUTIQUE_REPO = "https://github.com/GoogleCloudPlatform/microservices-demo.git"
        BOUTIQUE_BRANCH = "release/v0.10.2" // like; "release/v0.10.2"
    }
    stages{
        stage("init"){ 
            steps{  
                script{
                    echo "init" 
                    utils = load "libs/utils.groovy"
                }
            } 
        }

        stage("Download Source"){ 
            steps{
                script{
                    echo "Download Souce" 
                    utils.downloadSource(BOUTIQUE_BRANCH)
                }
            } 
        } 

        stage("Build Images"){ 
            steps{  
                script{
                    echo "Build Images" 
                    utils.buildImages()
                }
            } } //CVE check, too



        stage("Push Images"){ steps{  echo "Push Images" } }
        // create helm and plan manifest from helm template

    }
}