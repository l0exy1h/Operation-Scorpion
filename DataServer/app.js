const express = require('express')
const app = express()

// parse the data as json 
const dbAccessRoute = '/queryOS'
app.use(dbAccessRoute, express.json())

// connect the pgclient (authentication method = trust)
const pg = require('pg')
const db = new pg.Client("postgres://REDACTED")
db.connect()

// listen to post requests
app.post(dbAccessRoute, postHandler)
function postHandler(req, res) {
	res.setHeader('Content-Type', 'application/json')

	const body = req.body
	const pwd = body.pwd
	const query = body.query

	if (pwd == 'trolololol' && query) {

		db.query(query, (err, ret) => {
			if (err) {
				console.error(`db query error:\n err = ${err}\n query = ${query}`)
				return res.end(JSON.stringify({"err": `${err}`}))
			}
			const rows = ret.rows
			res.end(rows ? JSON.stringify(rows) : '{}')
		})

	}

	else {
		console.log(`invalid password or empty query:\n pwd = ${pwd}\n query = ${query}`)
		res.end("oof")
	}
}

// https server
// const https = require('https');
// const fs = require('fs');
// const sslOptions = {
// 	key: fs.readFileSync('server.key'),
// 	cert: fs.readFileSync('server.cert')
// }
// const server = https.createServer(sslOptions, app)

// setup the http server
const server = require('http').createServer(app)

// listen ports
const port = 3000
const host = '0.0.0.0'
server.listen(port, host, (err) => {
	if (err) {
		return console.error("can't create the nodeJS server", err)
	}
	console.log(`Server running at ${host}:${port}`)
})
