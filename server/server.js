const express = require('express');
var MongoClient = require('mongodb').MongoClient
const bodyParser= require('body-parser');
const db = require('./config/db');

const app = express();

const port = process.env.PORT || 5000;

app.use(bodyParser.urlencoded({extended: true}));

MongoClient.connect(db.url, (err, database) => {
    if (err) return console.log(err);
    let db = database.db("david-dev");
    require('./app/routes')(app, db);

    app.listen(port, () => {
        console.log(`listening on port ${port}`);
    })
})

