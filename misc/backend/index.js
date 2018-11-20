'use strict';

const express = require('express');
const puppeteer = require('puppeteer');
const {URL} = require('url');
const log4js = require('log4js');
log4js.configure({
  appenders: {
    out: {type: 'stdout'},
    app: {type: 'file', filename: 'webbkoll-backend.log'},
  },
  categories: {
    default: {
      appenders: ['out', 'app'],
      level: 'info',
    },
  },
});

const logger = log4js.getLogger();

const PORT = process.env.PORT || 8100;
const app = express();

app.get('/', async (request, response) => {
  const url = request.query.fetch_url;

  try {
    const parsedUrl = new URL(request.query.fetch_url);
    if (!['http:', 'https:'].includes(parsedUrl.protocol)) {
      return response.status(500).type('application/json').send(JSON.stringify({
        'success': false,
        'reason': 'Failed to fetch this URL: invalid URL',
      }));
    }
  } catch (err) {
    return response.status(500).type('application/json').send(JSON.stringify({
      'success': false,
      'reason': 'Failed to fetch this URL: invalid URL',
    }));
  }

  logger.info('Trying ' + url);

  const timeout = request.query.timeout || 15000;
  const browser = await puppeteer.launch({headless: true});
  const viewport = {
    width: 1920,
    height: 1080,
  };

  try {
    const context = await browser.createIncognitoBrowserContext();
    const page = await context.newPage();
    const client = await page.target().createCDPSession();

    await page.setViewport(viewport);
    await page.setUserAgent('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36');

    let responses = [];
    page.on('response', (response) => {
      responses.push({
        'url': response.url(),
        'remote_address': response.remoteAddress(),
        'headers': response.headers()
      });
    });

    await client.send('Security.enable');
    let securityInfo = {};
    client.on('Security.securityStateChanged', state => {
      securityInfo = state;
    });

    /*
    let requests = [];
    page.on('request', (request) => {
      requests.push({
        'url': request.url(),
        'method': request.method(),
        'headers': request.headers()
      });
    });
    */

    // On some broken pages the load event is never fired, so we don't wait for that
    const pageResponse = await page.goto(url, {
      waitUntil: ['domcontentloaded', 'networkidle2'],
      timeout: timeout,
    });

    let content = await page.content();
    // Necessary to get *ALL* cookies
    let cookies = await client.send('Network.getAllCookies');
    //let localStorage = await page.evaluate(() => { return {...localStorage}; });
    // ^- prettier, but we've got to truncate things for sanity:
    let localStorage = await page.evaluate(() => {
      let tmpObj = {};
      let keys = Object.keys(localStorage);
      for (let i = 0; i < keys.length; ++i) {
        tmpObj[keys[i].substring(0,100)] = localStorage.getItem(keys[i]).substring(0,100);
      }
      return tmpObj;
    });

    let title = await page.title();
    let finalUrl = await page.url();

    let responseHeaders = pageResponse.headers();
    responseHeaders.status = pageResponse.status();
    responseHeaders.remote_address = pageResponse.remoteAddress();

    let webbkollStatus = 200;
    let results = {};
    if (responseHeaders.status >= 200 && responseHeaders.status <= 299) {
      logger.info('Successfully checked ' + url);
      results = {
        'success': true,
        'input_url': url,
        'final_url': finalUrl,
        'responses': responses,
        'response_headers': responseHeaders,
        'cookies': cookies.cookies,
        'localStorage': localStorage,
        'security_info': securityInfo,
        'content': content
      };
    } else {
      logger.warn('Failed checking ' + url + ': ' + responseHeaders.status);
      results = {
        'success': false,
        'reason': 'Failed to fetch this URL: ' + responseHeaders.status + ' (' + title + ')',
      };
      webbkollStatus = 500;
    }

    response.status(webbkollStatus).type('application/json').send(JSON.stringify(results));
    await context.close();
  } catch (err) {
    logger.warn('Failed checking ' + url + ': ' + err.toString());
    response.status(500).type('application/json').send(JSON.stringify({
      'success': false,
      'reason': 'Failed to fetch this URL: ' + err.toString(),
    }));
  }
  await browser.close();
  logger.info('Finished with ' + url);
});

app.get('/status', async (request, response) => {
  response.status(200).send('OK!');
});

app.listen(PORT, function() {
  logger.info(`Webkoll backend listening on port ${PORT}`);
});
