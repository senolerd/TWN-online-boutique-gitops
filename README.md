
This portfolio project: 
- Pulls Google Online Boutique project source code branch, 
- creates container images, 
- pushes images to AWS ECR
- creates a helm chart and a monolithic manifest
- expects ArgoCD updates with the new chart or manifest



AWS 



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


