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
    imgRegistryLogin()
    def services = [
        adservice:[name: "adservice", srcDir: "adservice"], 
        // cartservice:[name: "cartservice", srcDir: "cartservice/src"],
        // checkoutservice:[name: "checkoutservice", srcDir: "checkoutservice"],
        // currencyservice:[name: "currencyservice", srcDir: "currencyservice"],
        // emailservice:[name: "emailservice", srcDir: "emailservice"],
        // frontend:[name: "frontend", srcDir: "frontend"],
        // paymentservice:[name: "paymentservice", srcDir: "paymentservice"],
        // productcatalogservice:[name: "productcatalogservice", srcDir: "productcatalogservice"],
        // recommendationservice:[name: "recommendationservice", srcDir: "recommendationservice"],
        // shippingservice:[name: "shippingservice", srcDir: "shippingservice"],
        // shoppingassistantservice:[name: "shoppingassistantservice", srcDir: "shoppingassistantservice"],
    ]

    def imageVersion = "${GIT_COMMIT[0..6]}-b${BUILD_NUMBER}"

    for (service in services.entrySet()){
        dir("${WORKSPACE}/microservices-demo/src/$service.value.srcDir"){
            sh """ podman build \
                -t ${service.value.name}:${BOUTIQUE_BRANCH.replace('/','-')}-${imageVersion} \
                --label "SCM_VERSION=${BOUTIQUE_BRANCH}" .
            """
        }
    }
}

def ecrLogin(){
    echo "ecrLogin"
}

def getAwsCallerIdentity(){
    echo "getAwsCallerIdentity"
}

return this
