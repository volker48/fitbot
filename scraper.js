var next = function (i) {
    if (i > 0) {
        i++;
        return 'https://www.brainyquote.com/quotes/authors/a/arnold_schwarzenegger_' + i + '.html';
    } else {
        return 'https://www.brainyquote.com/quotes/authors/a/arnold_schwarzenegger.html';
    }
};

var scraper = {
    iterator: 'div.boxyPaddingBig',
    data: {
        quote: {
            sel: 'span.bqQuoteLink a',
            method: 'text'
        },
        author: {
            sel: 'div.bq-aut a',
            method: 'text'
        }
    }
};

var params = {
    throttle: 1000,
    limit: 4,
    concat: true,
    scrape: scraper,
    done: function (data) {
        artoo.saveJson(data, {filename: 'quotes.json'})
    }
};
artoo.ajaxSpider(next, params);
