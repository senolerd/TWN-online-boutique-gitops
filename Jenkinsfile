def utils
pipeline{
    agent any 
    environment{
        // Boutique Source
        BOUTIQUE_REPO = "https://github.com/GoogleCloudPlatform/microservices-demo.git"
        BOUTIQUE_BRANCH = "release/v0.10.2"
        AWS_CRED_ID = "aws_devops_cred"
        AWS_REGION = "us-east-1"
    }
    stages{
        stage("init"){ 
            steps{  
                script{
                    echo "init for Boutique ${BOUTIQUE_BRANCH} has started" 
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