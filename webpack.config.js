const path = require("path");

module.exports = {
    entry: "./app/js/app.js",
    output: {
        path: path.resolve(__dirname, "build"),
        //path: __dirname + "/build/app/js",
        filename: "app.js"
    },
    module: {
        rules: []
    },
    devServer: {
        host: "0.0.0.0",
        port: 8000
    }
};