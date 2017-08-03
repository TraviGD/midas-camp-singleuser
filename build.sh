#!/bin/sh
docker build -t 127.0.0.1:5000/midas-camp-singleuser . && docker push 127.0.0.1:5000/midas-camp-singleuser && for i in bluebonnet pricklypear jalapeno; do ssh root@$i docker pull 127.0.0.1:5000/midas-camp-singleuser & done
