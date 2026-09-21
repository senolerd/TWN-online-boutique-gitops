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
    echo "Boutique $branch images getting builded"
    def services = [
        adservice:[name:"adservice", buildDir: "src/adservice"], 
        cartservice:[name:"cartservice", buildDir: "src/cartservice/src"],
        checkoutservice:[name:"checkoutservice", buildDir: "src/checkoutservice"],
        currencyservice:[name:"currencyservice", buildDir: "src/currencyservice"],
        emailservice:[name:"emailservice", buildDir: "src/emailservice"],
        frontend:[name:"frontend", buildDir: "src/frontend"],
        paymentservice:[name:"paymentservice", buildDir: "src/paymentservice"],
        productcatalogservice:[name:"productcatalogservice", buildDir: "src/productcatalogservice"],
        recommendationservice:[name:"recommendationservice", buildDir: "src/recommendationservice"],
        shippingservice:[name:"shippingservice", buildDir: "src/shippingservice"],
        shoppingassistantservice:[name:"shoppingassistantservice", buildDir: "src/shoppingassistantservice"],
    ]
    for (service in services){
        echo "$service.key services name: $service.value.name, service building dir: $service.buildDir"
    }
}

return this