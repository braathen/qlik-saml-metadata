var express = require('express');
var fs = require('fs');
var util = require('util');
var QRS = require('qrs');
var path = require("path");
var xml2js = require('xml2js');
var _ = require("underscore");

var settings = {};
var arg = process.argv.slice(2);
arg.forEach(function(a) {
    var key = a.split("=");
    switch(key[0].toLowerCase()) {
        case "port":
            settings.port = key[1];
            break;
    }
});

var config = {
    authentication: 'certificates',
    host: 'Windows2012',
    useSSL: true,
    cert: 'C:\\ProgramData\\Qlik\\Sense\\Repository\\Exported Certificates\\.Local Certificates\\client.pem',
    key: 'C:\\ProgramData\\Qlik\\Sense\\Repository\\Exported Certificates\\.Local Certificates\\client_key.pem',
    ca: 'C:\\ProgramData\\Qlik\\Sense\\Repository\\Exported Certificates\\.Local Certificates\\root.pem',
    port: 4242,
    headerKey: 'X-Qlik-User',
    headerValue: 'UserDirectory=INTERNAL; UserId=sa_repository'
};

var app = express();
app.use('/css', express.static(path.join(__dirname, 'css')));

app.engine('html', function (filePath, options, callback) {
    fs.readFile(filePath, function (err, content) {
        if (err) return callback(new Error(err));
        var rendered = content.toString().replace('#entityid#', '' + options.entityid + '')
            .replace('#acs#', '' + options.acs + '')
            .replace('#nameidformat#', '' + options.nameidformat + '')
            .replace('#certificate#', '' + options.certificate + '');
        return callback(null, rendered);
    });
});

app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'html');

var qrs = new QRS(config);
var samlProxies = [];

qrs.request('GET', '/qrs/proxyservice', null, null)
    .then(function (data) {

        qrs.request('GET', util.format('/qrs/proxyservice/%s', data[0].id), null, null)
            .then(function (data) {

                var virtualProxies = _.filter(data.settings.virtualProxies, function (data) {
                    return data.headerAuthenticationMode == 3;
                });
                samlProxies = virtualProxies;

            }, function (err) {
                res.end('An error occurred: ', err);
            });

    }, function (err) {
        res.end('An error occurred: ', err);
    });


app.get('/:prefix/metadata', function (req, res) {

    var virtualProxy = _.filter(samlProxies, function (data) {
        return data.prefix.toLowerCase() == req.params.prefix.toLowerCase();
    });

    if (virtualProxy.length != 1) {
        res.status(404).send('<h1>404 Not Found</h1>');
        return;
    }

    qrs.request('GET', util.format('/qrs/virtualproxyconfig/%s/generate/samlmetadata', virtualProxy[0].id), null, null)
        .then(function (data) {

            qrs.request('GET', util.format('/qrs/download/samlmetadata/%s/saml_metadata_sp.xml', data.value), null, null)
                .then(function (data) {

                    res.format({
                        'application/xml': function () {
                            res.send(data);
                        }
                    });

                }, function (err) {
                    res.end('<h1>An error occurred</h1>');
                });

        }, function (err) {
            res.end('<h1>An error occurred</h1>');
        });
});

app.get('/:prefix/config', function (req, res) {

    var virtualProxy = _.filter(samlProxies, function (data) {
        return data.prefix.toLowerCase() == req.params.prefix.toLowerCase();
    });

    if (virtualProxy.length != 1) {
        res.status(404).send('<h1>404 Not Found</h1>');
        return;
    }

    // retrieve ticket to request metadata
    qrs.request('GET', util.format('/qrs/virtualproxyconfig/%s/generate/samlmetadata', virtualProxy[0].id), null, null)
        .then(function (data) {

            // download metadata
            qrs.request('GET', util.format('/qrs/download/samlmetadata/%s/saml_metadata_sp.xml', data.value), null, null)
                .then(function (data) {

                    var parser = new xml2js.Parser({mergeAttrs: true});
                    parser.parseString(data, function (err, result) {
                        var metadata = {};
                        metadata.entityid = result["md:EntityDescriptor"]["entityID"][0];
                        metadata.certificate = "-----BEGIN CERTIFICATE-----\r\n" + result['md:EntityDescriptor']['md:SPSSODescriptor'][0]['md:KeyDescriptor'][0]['KeyInfo'][0]['X509Data'][0]['X509Certificate'][0].replace(/(.{64})/g, "$1\r\n") + "\r\n-----END CERTIFICATE-----";
                        metadata.nameidformat = result['md:EntityDescriptor']['md:SPSSODescriptor'][0]['md:NameIDFormat'][0];
                        metadata.acs = result['md:EntityDescriptor']['md:SPSSODescriptor'][0]['md:AssertionConsumerService'][0]['Location'][0];
                        res.render('index', metadata);
                    });

                }, function (err) {
                    res.end('<h1>An error occurred</h1>');
                });

        }, function (err) {
            res.end('<h1>An error occurred</h1>');
        });

});

app.get('/*', function (req, res) {
    res.status(404).send('<h1>404 Not Found</h1>');
});

app.listen(settings.port);
