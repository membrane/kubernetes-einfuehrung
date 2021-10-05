
# Verwenden der öffentlichen Registry von Docker®

```
docker build -t predic8/sample-service:11 .

docker push predic8/sample-service:11 
```
lädt das image an registry-1.docker.io hoch


# Verwenden einer privaten Registry

```
docker login hub.predic8.de
```
(Passwort benötigt!)

```
docker build -t hub.predic8.de/predic8/sample-service:11 .

docker push hub.predic8.de/predic8/sample-service:11 
```

# Verwenden des REST APIs

```
curl 'http://localhost:8080/hello?name=Tobias'

curl http://localhost:8080/uuid

curl -T pom.xml -v http://localhost:8080/file/pom.xml

curl -o pom2.xml http://localhost:8080/file/pom.xml
```


# Urheberrecht

Kubernetes is a registered trademark of the Linux Foundation in the United States and other countries.

Docker and the Docker logo are trademarks or registered trademarks of Docker, Inc. in the United States and/or other countries.