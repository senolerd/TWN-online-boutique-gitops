
This portfolio project: 
- Pulls Google Online Boutique project source code branch, 
- creates container images, 
- pushes images to AWS ECR
- creates a helm chart and a monolithic manifest
- expects ArgoCD updates with the new chart or manifest

"While this pipeline handles artifact creation and Helm packaging, the actual Ingress workflow (Ingress/Gateway API resources) is out of scope for this CD process."
"The core application pipeline handles artifact creation and Helm packaging, while infrastructure-level networking (Ingress/Gateway API resources) is separated into a dedicated ArgoCD configuration."

If the EKS cluster will be created via AWS EKS web console, at node group creation stage, role named "AmazonEKSNodeRole" should be exist and can be used. If the role is not exist, it can be created manually with some AWS managed permission to make node group EC2 instances can interact with AWS service endpoints. eksctl handles role works by itself. With this role, node group instances can pull ECR images without any ECR credentials and login steps. Required permissions for node group role;
- AmazonEKS_CNI_Policy 
- AmazonEC2ContainerRegistryReadOnly
- AmazonEKSWorkerNodePolicy
- AmazonElasticContainerRegistryPublicReadOnly



Jenkins server/agent requirements:
- awscli
- helm
- Podman must be exist for image building and pushing. If jenkins is running as container, host podman sock present in container, and podman binaries should be installed like example Jenkins container run command bellow (w/ being awareness of not best practice mounting sock for PodmanInPodman, just rolling the wheel);
    podman run -d --name jenkins \
    --userns=keep-id \
    -v jenkins_home:/var/jenkins_home \
    -v /run/user/1000/podman/podman.sock:/run/podman/podman.sock:z \
    --restart=always \
    -e "CONTAINER_HOST=unix:///run/podman/podman.sock" \
    -e "TZ=America/Chicago" \
    -p 8080:8080 \
    docker.io/jenkins/jenkins:2.568.3-lts


