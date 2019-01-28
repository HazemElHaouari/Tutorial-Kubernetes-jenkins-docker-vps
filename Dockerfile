# stage 1
FROM node:latest as node
WORKDIR /app
COPY . .
RUN npm install
RUN ng build --prod

FROM nginx:latest
COPY --from=node /app/dist/angular-app /usr/share/nginx/html
