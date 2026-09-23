def downloadSource(branch){
    int sourceExist = sh(script: "stat microservices-demo > /dev/null 2>&1", returnStatus:true)
    if (sourceExist != 0){
        // Todo: If user decided to change branch at consecutive runs it will be problem. Branch should be checked, too.
        // At this time, Pipeline assumes same branch will be used from first pipeline execute.
        echo "Boutique $branch branch will be pulled"
        sh(script:"git clone --depth 1 --branch $branch ${env.BOUTIQUE_REPO}", returnStatus: true)
    } else {echo "Boutique source is exist, download skipped"}
    env.BOUTIQUE_SCR_DIR = "microservices-demo/src"
}

def buildImages(){
    ecrLogin()
    def services = [
        // adservice:[repo: "adservice", srcDir: "adservice"], 
        // cartservice:[repo: "cartservice", srcDir: "cartservice/src"],
        // checkoutservice:[repo: "checkoutservice", srcDir: "checkoutservice"],
        // currencyservice:[repo: "currencyservice", srcDir: "currencyservice"],
        // emailservice:[repo: "emailservice", srcDir: "emailservice"],
        frontend:[repo: "frontend", srcDir: "frontend"],
        // paymentservice:[repo: "paymentservice", srcDir: "paymentservice"],
        // productcatalogservice:[repo: "productcatalogservice", srcDir: "productcatalogservice"],
        // recommendationservice:[repo: "recommendationservice", srcDir: "recommendationservice"],
        // shippingservice:[repo: "shippingservice", srcDir: "shippingservice"],
        // shoppingassistantservice:[repo: "shoppingassistantservice", srcDir: "shoppingassistantservice"],
    ]

    def imageVersion = "${GIT_COMMIT[0..6]}-b${BUILD_NUMBER}"

    for (service in services.entrySet()){
        def imageTag = "${AWS_USER_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${service.value.repo}:${BOUTIQUE_BRANCH.replace('/','-')}-${imageVersion}"
        dir("${WORKSPACE}/microservices-demo/src/$service.value.srcDir"){
            sh """ 
            sed -i 's/^ARG BUILDPLATFORM.*/# &/' Dockerfile
            podman build -t ${imageTag} --label "SCM_VERSION=${BOUTIQUE_BRANCH}" . 
            """
        }
        pushImage(service.value.repo, imageTag)
    }
}

def ecrLogin(){
    echo "ecrLogin"
    withCredentials([usernamePassword(credentialsId: 'aws_devops_cred', passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
        env.AWS_USER_ID = sh(script:'aws sts get-caller-identity --query "Account" --output text', returnStdout: true).trim()
        echo "CALLER ID: $AWS_USER_ID"
        sh '''
            aws ecr get-login-password \
            --region $AWS_REGION | podman login --username AWS --password-stdin ${AWS_USER_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
        '''
    }
}

def pushImage(repo, imageTag){
    // Checking whether the repository is exist
    withCredentials([usernamePassword(credentialsId: 'aws_devops_cred', passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
        def isRepoExist =  sh(script:"aws ecr describe-repositories --repository-names ${repo} --region ${AWS_REGION} > /dev/null 2>&1", returnStatus: true)
        if (isRepoExist != 0){
            sh "aws ecr create-repository --repository-name ${repo} --region ${AWS_REGION}  > /dev/null 2>&1"
        }
    }
    sh (script:"podman push $imageTag", returnStdout:true)
}


return this
