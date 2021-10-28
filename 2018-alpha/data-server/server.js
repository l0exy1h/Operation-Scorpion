//Import requiered packages
const express = require('express');
const {Client} = require('pg');

//Create the conection to the postgres servers
// ------------------------------------------------
const clientOS = new Client({
	connectionString: "REDACTED"
});
clientOS.connect();

const clientPTS = new Client({
	connectionString: "REDACTED"
});
clientPTS.connect();




//Create the express app
//-----------------------------------------------
const bodyParser = require('body-parser');
const app = express();

// parse application/json
app.use(bodyParser.json());

function foo(db) {
	return (req, res) => {
		res.setHeader('Content-Type', 'application/json');
		console.log("Receiving request");
		if(req.body.query) {
			console.log(req.body.query);
			db.query(req.body.query, (err, r) => {
				if (err) throw err;
				rows = [];
				if (r.rows != null) {
					for(let row of r.rows){
						rows.push(row);
					}
				}
				response = JSON.stringify(rows);
				console.log(response);
				res.end(response);
			});
		}
	}
}

//Handle a post request at /query
app.post('/queryOS', foo(clientOS));
app.post('/queryPTS', foo(clientPTS));

const port = process.env.PORT || 8080;

//Start listening
const server = app.listen(port, function () {
   console.log("App listening at ${host}")
});

