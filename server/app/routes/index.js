
const offersRoutes = require('./offers_routes');

module.exports = function(app, db) {
    offersRoutes(app, db);
    //other routes can go here too
}