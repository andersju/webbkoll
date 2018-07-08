'use strict';

const express = require('express');
const puppeteer = require('puppeteer');
const {URL} = require('url');
require('console-stamp')(console, 'HH:MM:ss.l');

const PORT = process.env.PORT || 8100;
const app = express();

app.get('/', async (request, response) => {
  const url = request.query.fetch_url;

  try {
    const url_parsed = new URL(request.query.fetch_url);
    if (!['http:', 'https:'].includes(url_parsed.protocol)) {
      return response.status(500).send('Invalid URL.');
    }
  } catch (err) {
    return response.status(500).send('Invalid URL.');
  }

  console.log('Trying ' + url);

  const timeout = request.query.timeout || 15000;
  const browser = await puppeteer.launch({headless: true});
  const viewport = {
    width: 1920,
    height: 1080,
  };

  try {
    const context = await browser.createIncognitoBrowserContext();
    const page = await context.newPage();

    await page.setViewport(viewport);
    await page.setUserAgent('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36 webbkoll.dataskydd.net');

    let requests = [];
    let responses = [];
    let response_headers = {};

    page.on('response', (response) => {
      responses.push({'url': response.url(), 'headers': response.headers()});
    });

    page.on('request', (request) => {
      let tmpHeaders = request.headers();
      let headersArr = [];

      // A little ugly, but the Webbkoll frontend expects headers in this format
      Object.keys(tmpHeaders).forEach(function(key, index) {
        headersArr.push({'name': key, 'value': tmpHeaders[key]});
      });

      requests.push({'url': request.url(), 'headers': headersArr});
    });

    await page._client.send('Network.enable');
    await page.goto(url, {waitUntil: ['load', 'domcontentloaded', 'networkidle0'], timeout: timeout});

    let content = await page.content();
    // Necessary to get *ALL* cookies
    let cookies = await page._client.send('Network.getAllCookies');
    let final_url = await page.url();

    // We're only interested in the response headers for the final URL
    responses.forEach(function(response) {
      if (response.url == final_url) {
        response_headers = response.headers;
      }
    });

    let success = false;
    if (response_headers['status'] >= 200 && response_headers['status'] <= 299) {
      success = true;
    }

    let results = {
      'success': success,
      'input_url': url,
      'final_url': final_url,
      'requests': requests,
      'response_headers': response_headers,
      'cookies': cookies.cookies,
      'content': content,
    };

    await context.close();
    response.type('application/json').send(JSON.stringify(results));
  } catch (err) {
    console.log(err.toString());
    let results = {
      'success': false,
      'reason': err.toString(),
    };
    response.status(500).send(JSON.stringify(results));
  }
  await browser.close();
  console.log('Finished with ' + url);
});

app.get('/status', async (request, response) => {
  response.status(200).send('OK!');
});

app.listen(PORT, function() {
  console.log(`Webkoll backend listening on port ${PORT}`);
});
