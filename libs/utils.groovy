services = [
    // adservice:[repo: "adservice", srcDir: "adservice", port: "9555"],
    // cartservice:[repo: "cartservice", srcDir: "cartservice/src", port: "7070"],
    // checkoutservice:[repo: "checkoutservice", srcDir: "checkoutservice", port: "5050"],
    // currencyservice:[repo: "currencyservice", srcDir: "currencyservice", port: "7000"],
    // emailservice:[repo: "emailservice", srcDir: "emailservice", port: "8080"],
    frontend:[repo: "frontend", srcDir: "frontend", port: "8080"],
    // paymentservice:[repo: "paymentservice", srcDir: "paymentservice", port: "50051"],
    // productcatalogservice:[repo: "productcatalogservice", srcDir: "productcatalogservice", port: "3550"],
    // recommendationservice:[repo: "recommendationservice", srcDir: "recommendationservice", port: "8080"],
    // shippingservice:[repo: "shippingservice", srcDir: "shippingservice", port: "50051"],
    // shoppingassistantservice:[repo: "shoppingassistantservice", srcDir: "shoppingassistantservice", port: "8080"],
]

def downloadSource(branch){
    sh"""
        rm -rf microservices-demo
        git clone --depth 1 --branch $branch ${env.BOUTIQUE_REPO}
    """
    env.BOUTIQUE_SCR_DIR = "microservices-demo/src"
}

def buildImages(){
    ecrLogin()
    
    def imageVersion = "${GIT_COMMIT[0..6]}-b${BUILD_NUMBER}"

    for (service in services.entrySet()){
        service.value.imguri = "${ECR_REGISTER}/${service.value.repo}:${BOUTIQUE_BRANCH.replace('/','-')}-${imageVersion}"

        dir("${WORKSPACE}/microservices-demo/src/$service.value.srcDir"){
            sh """ 
            sed -i 's/^ARG BUILDPLATFORM.*/# &/' Dockerfile
            podman build -t ${service.value.imguri} --label "SCM_VERSION=${BOUTIQUE_BRANCH}" . 
            """
        }
        // pushImage(service.value.repo, service.value.imguri)
    }
}

def ecrLogin(){
    // "env.AWS_USER_ID" and "env.ECR_REGISTER" are defined here, too with registry login
    echo "ecrLogin"
    withCredentials([usernamePassword(credentialsId: 'aws_devops_cred', passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
        env.AWS_USER_ID = sh(script:'aws sts get-caller-identity --query "Account" --output text', returnStdout: true).trim()
        env.ECR_REGISTER = "${AWS_USER_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        echo "CALLER ID: $AWS_USER_ID"
        sh '''
            aws ecr get-login-password \
            --region $AWS_REGION | podman login --username AWS --password-stdin ${AWS_USER_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
        '''
    }
}

// 
// 
// Pushing can be moved as stage
// 
// 

def pushImages(){
    withCredentials([usernamePassword(credentialsId: 'aws_devops_cred', passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
        for (service in services.entrySet()){
            // Checking whether the repository is exist
            def isRepoExist =  sh(script:"aws ecr describe-repositories --repository-names ${service.value.repo} --region ${AWS_REGION} > /dev/null 2>&1", returnStatus: true)
            if (isRepoExist != 0){
                sh "aws ecr create-repository --repository-name ${service.value.repo} --region ${AWS_REGION}  > /dev/null 2>&1"
            }
    
            sh "podman push $service.value.imguri"
        }
    }
    
}



return this
