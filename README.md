














Podman must be exist for image build, and pushing. If jenkins is running in container, host podman sock present in container, like example Jenkins container run;

podman run -d --name jenkins \
--userns=keep-id \
-v jenkins_home:/var/jenkins_home \
-v /run/user/1000/podman/podman.sock:/run/podman/podman.sock:z \
--restart=always \
-e "CONTAINER_HOST=unix:///run/podman/podman.sock" \
-e "TZ=America/Chicago" \
-p 8080:8080 \
docker.io/jenkins/jenkins:2.568.3-lts