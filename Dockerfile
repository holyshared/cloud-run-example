FROM node:16

ARG WORKDIR=/var/app
RUN mkdir -p ${WORKDIR}
WORKDIR ${WORKDIR}

ADD package.json package.json
ADD yarn.lock yarn.lock
COPY src src

RUN yarn

CMD [ "yarn", "start" ]
