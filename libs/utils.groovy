services = [
    adservice:[repo: "adservice", srcDir: "adservice", port: 9555, rep: 1],
    cartservice:[repo: "cartservice", srcDir: "cartservice/src", port: 7070, rep: 1],
    checkoutservice:[repo: "checkoutservice", srcDir: "checkoutservice", port: 5050, rep: 1],
    currencyservice:[repo: "currencyservice", srcDir: "currencyservice", port: 7000, rep: 1],
    emailservice:[repo: "emailservice", srcDir: "emailservice", port: 8080, rep: 1],
    frontend:[repo: "frontend", srcDir: "frontend", port: 8080, rep: 1],
    paymentservice:[repo: "paymentservice", srcDir: "paymentservice", port: 50051, rep: 1],
    productcatalogservice:[repo: "productcatalogservice", srcDir: "productcatalogservice", port: 3550, rep: 1],
    recommendationservice:[repo: "recommendationservice", srcDir: "recommendationservice", port: 8080, rep: 1],
    shippingservice:[repo: "shippingservice", srcDir: "shippingservice", port: 50051, rep: 1],
    shoppingassistantservice:[repo: "shoppingassistantservice", srcDir: "shoppingassistantservice", port: 8080, rep: 1]
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
    
    env.APP_VERSION = "${BOUTIQUE_BRANCH.replace('/','-')}-${GIT_COMMIT[0..6]}-b${BUILD_NUMBER}"

    for (service in services.entrySet()){
        service.value.imguri = "${ECR_REGISTER}/${service.value.repo}:${env.APP_VERSION}"

        dir("${WORKSPACE}/microservices-demo/src/$service.value.srcDir"){
            sh """ 
                sed -i 's/^ARG BUILDPLATFORM.*/# &/' Dockerfile
                podman build -t ${service.value.imguri} --label "SCM_VERSION=${BOUTIQUE_BRANCH}" . 
            """
        }
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

def helmChart(){

    def isChartExist = sh(script: "stat ${BOUTIQUE_HELM_CHART} > /dev/null 2>&1", returnStatus: true)
    if (1) { // create new helm chart
    // if (isChartExist != 0) { // create new helm chart
        echo 'CREATING HELM CHART'
        sh "helm create ${BOUTIQUE_HELM_CHART}"

        // Cleaning new chart
        dir(env.BOUTIQUE_HELM_CHART) {
            sh """
                rm -rf templates/*
                echo "" > values.yaml
            """

            // Creating templates and values.yaml 
            for (service in services.entrySet()){ 
                _addValuesYamlLine(service.value)
                _addDeploymentAndServiceTemplate(service.value)
            }

            // Create new Chart.yaml
            _updateChartYaml(env.APP_VERSION)

        }

    }
    else { // update chart
        echo "UPDATING EXIST HELM CHART"
    }
}


def _addValuesYamlLine(Map service){
    // Modifying values.yaml
    sh """
        cat <<- EOF >> values.yaml
        # ${service.repo} variables
        ${service.repo}:
            port: ${service.port}
            imguri: ${service.imguri}
            replica: ${service.rep}

        EOF
    """.stripIndent()
}

def _addDeploymentAndServiceTemplate(Map service){
    // Creating microservice deployment and service manifest templates
    sh """
        cat <<- EOF >> templates/${service.repo}.yaml
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: "${service.repo}-deployment"
          labels:
            app: "${service.repo}"
        spec:
          replicas: {{ .Values.${service.repo}.replica }}
          selector:
            matchLabels:
              app: "${service.repo}"
          template:
            metadata:
              labels:
                app: "${service.repo}"
            spec:
              containers:
              - name: "${service.repo}"
                image: "{{ .Values.${service.repo}.imguri }}"
                ports:
                - containerPort: {{ .Values.${service.repo}.port }}
        ---
        apiVersion: v1
        kind: Service
        metadata:
          name: "${service.repo}"
        spec:
          selector:
            app: "${service.repo}"
          ports:
          - protocol: TCP
            port: {{ .Values.${service.repo}.port }}
            targetPort: {{ .Values.${service.repo}.port }}

        EOF
    """.stripIndent()
}

def _updateChartYaml(appver){

    sh """
        cat << EOF > Chart.yaml
        apiVersion: v2
        name: boutique-helm
        description: A Helm chart for Kubernetes
        type: application
        version: ${env.BOUTIQUE_HELM_CHART_VER}
        appVersion: "${env.APP_VERSION}"

        EOF
    """.stripIndent()
}

return this

