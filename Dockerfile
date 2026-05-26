FROM node:18-alpine
WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 5200

CMD ["node", "app.js", "--port=5200", "--dbuser=app", "--dbpassword=password", "--dbname=mywebapp"]
