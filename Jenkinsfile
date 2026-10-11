def utils
pipeline{
    agent any 
    environment{
        // Boutique Source
        BOUTIQUE_REPO = "https://github.com/GoogleCloudPlatform/microservices-demo.git"
        BOUTIQUE_BRANCH = "release/v0.10.7"
        BOUTIQUE_HELM_CHART_NAME = "boutique-helm"
        BOUTIQUE_HELM_CHART_VER = "0.1.1"

        // AWS
        AWS_CRED_ID = "aws_devops_cred" //
        AWS_REGION = "us-east-1"

        // Jenkins server's GitHub bot identity for helm chart version bump Up
        CI_BOT_GITHUB_CRED = 'boutique_git_devops_bot' // GitHub repo scoped SSH key
        CI_BOT_USERNAME = "Alfred Pennyworth"
        CI_BOT_EMAIL = "alfred_pennyworth@wayneenterprises.com"
        CI_BOT_COMMIT_SIGN = "[skip ci]"

        // Trivy CVE scanner
        CVE_SCAN_ENABLED = true
        CVE_SEVERITY = "HIGH,CRITICAL" // "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"
        CVE_SCAN_REPORT_FORMAT = "json"
        CVE_USE_VULNERABLE_IMAGE = false // "true" is just and only for pipeline testing, not for dev or prod
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
                    utils.downloadSource(BOUTIQUE_BRANCH)
                }
            } 
        } 

        stage("Build Images"){ 
            steps{  
                script{
                    utils.buildImages()
                }
            } 
        } 

        stage("Image CVE Scan"){ 
            when { 
                expression { env.CVE_SCAN_ENABLED.toBoolean() } 
            } 
            steps{  
                script{
                    utils.cveScan()
                }
            } 
        } 

        stage("Push images to ECR"){ 
            steps{  
                script{
                    utils.pushImages()
                }
            } 
        } 

        stage("Helm chart creating"){ 
            steps{  
                script{
                    utils.helmChartCreate() // creates new chart
                    utils.helmChartLinting() // chart linging check
                    
                }
            } 
        } 

        stage("Helm Chart Version Bump Up"){ 
            steps{  
                script{
                    utils.updateGithubHelmChart()
                }
            } 
        } 

    }
}