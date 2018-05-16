var ObjectID = require('mongodb').ObjectID;

module.exports = function(app, db) {

    app.get('/offers/:id', (req, res) => {
        const id = req.params.id;
        // const details = { '_id': new ObjectID(id) };
        // db.collection('open-offers').findOne(details, (err, item) => {
        //     if (err) {
        //         res.send({'error':'an error has occured'});
        //     } else {
        //         res.send(item);
        //     }
        // });
        res.send({'id': id})
    });

    app.post('/offers', (req, res) => {
      console.log(req.body)
      res.send('Hello')
    });
  };