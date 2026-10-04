
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
    // shoppingassistantservice:[repo: "shoppingassistantservice", srcDir: "shoppingassistantservice", port: 8080, rep: 1] Asking google's alloydb (postgre)
]

def downloadSource(branch){
  // A fresh start
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
          // small fixes per service
          _minorPatches(service.key)

          sh """ 
              sed -i 's/^ARG BUILDPLATFORM.*/# &/' Dockerfile
              podman build -t ${service.value.imguri} --label "SCM_VERSION=${BOUTIQUE_BRANCH}" . 
              podman image prune -f
          """
        }
    }
}


def _minorPatches(service){
  
  // shoppingasistanceservice is missin "asyncio", adding to requirements.txt
  if ( service == "shoppingassistantservice" ) {
    sh 'echo aiohttp >> requirements.txt'
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

    def isChartExist = sh(script: "stat ${BOUTIQUE_HELM_CHART_NAME} > /dev/null 2>&1", returnStatus: true)

    echo 'CREATING HELM CHART'
    sh "rm -rf  ${BOUTIQUE_HELM_CHART_NAME}"
    sh "helm create ${BOUTIQUE_HELM_CHART_NAME}"
    // Cleaning the new chart
    dir(env.BOUTIQUE_HELM_CHART_NAME) {
        sh """
            rm -rf templates/*
            echo "" > values.yaml
        """
        
        // Creating templates and values.yaml 
        for (service in services.entrySet()){ 
            _addServiceVarToValuesYaml(service.value)
            _addDeploymentAndServiceTemplate(service.value)
        }

        // Create new Chart.yaml
        _createHelmChartYaml(env.APP_VERSION)
    }

    // Adding aux services template
    _addRedis()
}

def _addServiceVarToValuesYaml(Map service){
    // Modifying values.yaml
    sh """
        cat <<- EOF >> values.yaml
        # ${service.repo} variables
        ${service.repo}:
            name: ${service.repo}
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
                env:
                - name: PORT
                  value: "{{ .Values.${service.repo}.port }}"
                - name: AD_SERVICE_ADDR
                  value: "{{ .Values.adservice.name }}:{{ .Values.adservice.port }}"
                - name: CART_SERVICE_ADDR
                  value: "{{ .Values.cartservice.name }}:{{ .Values.cartservice.port }}"
                - name: CHECKOUT_SERVICE_ADDR
                  value: "{{ .Values.checkoutservice.name }}:{{ .Values.checkoutservice.port }}"
                - name: CURRENCY_SERVICE_ADDR
                  value: "{{ .Values.currencyservice.name }}:{{ .Values.currencyservice.port }}"
                - name: EMAIL_SERVICE_ADDR
                  value: "{{ .Values.emailservice.name }}:{{ .Values.emailservice.port }}"
                - name: FRONTEND_SERVICE_ADDR
                  value: "{{ .Values.frontend.name }}:{{ .Values.frontend.port }}"
                - name: PAYMENT_SERVICE_ADDR
                  value: "{{ .Values.paymentservice.name }}:{{ .Values.paymentservice.port }}"
                - name: PRODUCT_CATALOG_SERVICE_ADDR
                  value: "{{ .Values.productcatalogservice.name }}:{{ .Values.productcatalogservice.port }}" 
                - name: RECOMMENDATION_SERVICE_ADDR
                  value: "{{ .Values.recommendationservice.name }}:{{ .Values.recommendationservice.port }}" 
                - name: SHIPPING_SERVICE_ADDR
                  value: "{{ .Values.shippingservice.name }}:{{ .Values.shippingservice.port }}" 
                - name: SHOPPING_ASSISTANT_SERVICE_ADDR
                  value: "null"                  
                - name: REDIS_ADDR
                  value: "redis-cart:6379"
                - name: ENABLE_SHOPPING_ASSISTANT
                  value: "false"
                - name: DISABLE_PROFILER
                  value: "1"
                - name: DISABLE_TRACING
                  value: "1"
                - name: DISABLE_DEBUGGER
                  value: "1"
                - name: REGION
                  value: "us-east-1"
                - name: PROJECT_ID
                  value: "hello1"
                - name: GCP_PROJECT
                  value: "hello2"
                - name: GOOGLE_CLOUD_PROJECT
                  value: "hello3"
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

def _createHelmChartYaml(appver){

    sh """
        cat << EOF > Chart.yaml
        apiVersion: v2
        name: boutique-helm
        description: A Helm chart for Kubernetes
        type: application
        version: "${env.BOUTIQUE_HELM_CHART_VER}+${env.APP_VERSION}"
        appVersion: "${env.APP_VERSION}"
        EOF
    """.stripIndent()
}



def _addRedis(){

    sh """
      cat << EOF > ${env.BOUTIQUE_HELM_CHART_NAME}/templates/redis-cart.yaml
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: "redis-cart-deployment"
        labels:
          app: "redis-cart"
      spec:
        replicas: 1
        selector:
          matchLabels:
            app: "redis-cart"
        template:
          metadata:
            labels:
              app: "redis-cart"
          spec:
            containers:
            - name: "redis-cart"
              image: "docker.io/redis:latest"
              ports:
              - containerPort: 6379
      ---
      apiVersion: v1
      kind: Service
      metadata:
        name: "redis-cart"
      spec:
        selector:
          app: "redis-cart"
        ports:
        - protocol: TCP
          port: 6379
          targetPort: 6379
      EOF
    """.stripIndent()








}


def updateGithubHelmChart(){
    sh """ 
        git config --replace-all user.email ${env.CI_BOT_EMAIL}
        git config --replace-all user.name ${env.CI_BOT_USERNAME}
        git add .
        git commit -m "Helm chart update for ${env.APP_VERSION} ${CI_BOT_COMMIT_SIGN}"
    """
    sshagent(credentials: ['mac_rsa_priv'], executable: '') {
        sh 'git push origin HEAD:main'
    }

}







return this