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
    def services = [
        adservice:[name: "adservice", srcDir: "adservice"], 
        cartservice:[name: "cartservice", srcDir: "cartservice/src"],
        checkoutservice:[name: "checkoutservice", srcDir: "checkoutservice"],
        currencyservice:[name: "currencyservice", srcDir: "currencyservice"],
        emailservice:[name: "emailservice", srcDir: "emailservice"],
        frontend:[name: "frontend", srcDir: "frontend"],
        paymentservice:[name: "paymentservice", srcDir: "paymentservice"],
        productcatalogservice:[name: "productcatalogservice", srcDir: "productcatalogservice"],
        recommendationservice:[name: "recommendationservice", srcDir: "recommendationservice"],
        shippingservice:[name: "shippingservice", srcDir: "shippingservice"],
        shoppingassistantservice:[name: "shoppingassistantservice", srcDir: "shoppingassistantservice"],
    ]

    def imageVersion = "${GIT_COMMIT[0..6]}-b${BUILD_NUMBER}"

    echo "Git Commit first 7 letter: $imageVersion"
    for (service in services.entrySet()){
        dir("${WORKSPACE}/microservices-demo/src/$service.value.srcDir"){
            sh "podman build -t ${service.value.name}:${BOUTIQUE_BRANCH.replace('/','-')}-${imageVersion} ."
        }
    }
}

return this


// JENKINS_HOME=/var/jenkins_home
// GIT_PREVIOUS_SUCCESSFUL_COMMIT=5d5d03cedc8a789971215b0481436f89145de6cd
// JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
// CI=true
// HOSTNAME=37d2bbe2d4bc
// RUN_CHANGES_DISPLAY_URL=http://192.168.1.90:8080/job/test/47/display/redirect?page=changes
// NODE_LABELS=built-in
// HUDSON_URL=http://192.168.1.90:8080/
// SHLVL=0
// GIT_COMMIT=5d5d03cedc8a789971215b0481436f89145de6cd
// HOME=/var/jenkins_home
// BUILD_URL=http://192.168.1.90:8080/job/test/47/
// HUDSON_COOKIE=b4c92dc2-5244-48e3-9f60-701cb01f2f79
// JENKINS_SERVER_COOKIE=durable-7190c2fadc48570bd1d6b9ff3df70884d6b72f619c1a447143f9aae059f70e9f
// JENKINS_UC=https://updates.jenkins.io
// REF=/usr/share/jenkins/ref
// container=podman
// WORKSPACE=/var/jenkins_home/workspace/test
// CONTAINER_HOST=unix:///run/podman/podman.sock
// NODE_NAME=built-in
// RUN_ARTIFACTS_DISPLAY_URL=http://192.168.1.90:8080/job/test/47/display/redirect?page=artifacts
// BOUTIQUE_REPO=https://github.com/GoogleCloudPlatform/microservices-demo.git
// STAGE_NAME=Build Images
// GIT_BRANCH=origin/main
// EXECUTOR_NUMBER=3
// BUILD_DISPLAY_NAME=#47
// JENKINS_INCREMENTALS_REPO_MIRROR=https://repo.jenkins-ci.org/incrementals
// JENKINS_VERSION=2.568.3
// BOUTIQUE_BRANCH=release/v0.10.2
// RUN_TESTS_DISPLAY_URL=http://192.168.1.90:8080/job/test/47/display/redirect?page=tests
// HUDSON_HOME=/var/jenkins_home
// JOB_BASE_NAME=test
// PATH=/opt/java/openjdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
// BUILD_ID=47
// BOUTIQUE_SCR_DIR=microservices-demo/src
// BUILD_TAG=jenkins-test-47
// LANG=C.UTF-8
// JENKINS_URL=http://192.168.1.90:8080/
// JOB_URL=http://192.168.1.90:8080/job/test/
// GIT_URL=git@github.com:senolerd/TWN-online-boutique-gitops.git
// BUILD_NUMBER=47
// JENKINS_NODE_COOKIE=476485b2-7b76-43be-bc15-87211f4ecf8c
// JENKINS_SLAVE_AGENT_PORT=50000
// RUN_DISPLAY_URL=http://192.168.1.90:8080/job/test/47/display/redirect
// HUDSON_SERVER_COOKIE=dc97c56ecc77c416
// JOB_DISPLAY_URL=http://192.168.1.90:8080/job/test/display/redirect
// JOB_NAME=test
// COPY_REFERENCE_FILE_LOG=/var/jenkins_home/copy_reference_file.log
// JAVA_HOME=/opt/java/openjdk
// PWD=/var/jenkins_home/workspace/test
// GIT_PREVIOUS_COMMIT=5d5d03cedc8a789971215b0481436f89145de6cd
// WORKSPACE_TMP=/var/jenkins_home/workspace/test@tmp
// TZ=America/Chicago