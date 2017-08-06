---
layout: post
date: 2016-09-03
title: How to Run Unit Tests Pre-Commit
header: How to Run Unit Tests Pre-Commit
description: How to enforce test-suite maintenance and cleaner code by running unit-tests prior to GIT commit.
---

Today I'd like to walkthrough how to run your automated suite of unit tests on a pre-commit hook. *Don't get me wrong*, this is not a replacement for a Continuous Integration platform. A good CI that runs all your unit, integration, and feature specs is irreplacable. This is meant to be an intermediary step, similar to a linter or something. If your project is open-source, or has an extremely high volume of daily commits, running the unit tests prior to commit can filter bad code from polluting your commit history and prevents unnecessary load on your CI.

Let's start with a couple of unit tests written in Mocha/Chai. If your team doesn't have a suite of unit tests already, now's a great time to start. Unit tests are the cornerstone of any great software application; they allow you to refactor with impunity, and act as the contract to how your code should work. Alright, time to get *off my soapbox* - let's get started.

~~~ javascript
  var expect = require("chai").expect;
  var RomanNumerals = require("../RomanNumerals");

  describe("RomanNumerals", function () {
    describe("#toRoman", function () {
      it("calculates 1001", function () {
        expect(RomanNumerals.toRoman(1001)).to.equal("MI");
      });

      it("calculates 10", function () {
        expect(RomanNumerals.toRoman(10)).to.equal("X");
      });

      it("calculates 4", function () {
        expect(RomanNumerals.toRoman(4)).to.equal("IV");
      });
    });
  });
~~~

We've got our RomanNumerals object with a function toRoman, which takes a single integer and returns the roman numeral equivalent. Pretty straight forward. You can run these tests with a simple `mocha` from the command-line.

Next we'll install <a href="https://www.npmjs.com/package/pre-commit">pre-commit</a>, a great little NPM package that abstracts the hook creation process for you. Under the hood, it's just going to create the git hook from our package.json config and symlink to your .git/hooks dir. Kinda cool.

~~~ text
  npm install pre-commit --save-dev
~~~

Now, we just need to add the precommit config to your package.json.

~~~ json
  {
    "name": "pre_commit_demonstration",
    "version": "1.0.0",
    "scripts": {
      "test": "mocha"
    },
    "devDependencies": {
      "chai": "^3.5.0",
      "mocha": "^3.0.2",
      "pre-commit": "^1.1.3"
    },
    "precommit": [ "test" ]
  }
~~~

Two important updates here.

  1. We added a scripts object to run mocha through the `npm test` command. The pre-commit array expects valid npm commands.

  2. We added the precommit array to the bottom of our package.json. Basically, as stated above, it's just going to loop over these commands and run them prior to the commit taking place. If any of the commands (test, in our case) return an exit code, it will prevent the commit from happening and drop a pretty nice little error message in the console.

For the sake of this demonstration, let's fast forward to the year 2116. A new developer comes along your project and has never heard of roman numerals. He decides that "Z" makes more sense as the 1000 character. Unfortunately, after making the change, he gets into a deep conversation about how awesome the flame decals on his hoverboard are, and forgets to update the tests. As he commits his changes to master..

<p class="row">
  <img class="col-md-6 col-md-offset-3" src="/assets/img/precommit_failure.png" alt="Failure" />
</p>

Quickly, he changes the test and commits without error. Our git repo is spared the "fixing tests" commit pollution and the CI didn't have to run for two hours over all our feature and integration specs just to fail on a single unit-test. Pretty great, huh?

I hope you've found this information useful. If you have any questions or concerns please feel free to follow me on Twitter.
