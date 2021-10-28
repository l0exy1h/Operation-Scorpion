const http = require("http");
const hostname = '0.0.0.0';
const port = 3000;

const requestHandler = (req, res) => {
        console.log("http request received!");
        res.statusCode = 200;
        res.setHeader('Content-Type', 'test/plain');
        res.end('Hello World\n');
};
const server = http.createServer(requestHandler);

server.listen(port, hostname, (err) => {
        if (err) {
                return console.log('oof', err);
        }
        console.log(`Server running at ${port}`);
})