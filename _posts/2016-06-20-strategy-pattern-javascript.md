---
layout: post
title: Strategy Pattern in JavaScript
date: 2016-06-20
---

<p>
  Over the last few years <a href="https://nodejs.org/en/" alt="NodeJS">NodeJS</a> has catapulted JavaScript into the backend scripting language scene. Major companies like Yahoo and Ebay have jumped on the Node train towards a speedy-fast, full-stack JavaScript ecosystem. As the Node community has grown, the push towards more traditional object-oriented principles has increased. Node now supports most major components of ES6, including syntactic sugar like class objects, block scope, and true object inheritance.
</p>

<p>
  The future of Node is a migration towards testable class objects with loosly-coupled modules. Unfortunately, this will mean a hard shift from the functional-programming patterns used today. Although a myriad of books have already covered design patterns, including the infamous <a href="https://www.amazon.com/Design-Patterns-Elements-Reusable-Object-Oriented-ebook/dp/B000SEIBB8" alt="Design Patterns">Design Patterns</a> by the Gang of Four, few authors have translated these patterns into JavaScript. I believe it'd be valuable to understand how we can use these patterns to build efficient, scalable applications in Node.
</p>

<p>
  One of the most common and easily translated patterns is the <a href="https://en.wikipedia.org/wiki/Strategy_pattern" alt="Strategy Pattern">Strategy Pattern.</a> The Strategy pattern allows us encapsulate complex domain logic and abstract the logic's implementation from the calling service. Let's take a look at an example.
</p>

<p>
  Let's assume your e-commerce site sells Widgets online and accepts a variety of payment methods. After a customer selects a payment type and enters their information, you create an object representation of that Payment Instrument in JavaScript and save the information as properties on that object like this:
</p>

<pre>
  <code class="javascript">
    var CreditCard = {
      this.methodType = "CREDIT_CARD",
      this.type = card_type,
      this.name = card_name,
      this.number = card_number,
      this.expiration = card_expiration,
      this.cvv = card_cvv,
    };
  </code>
</pre>

<p>
  When the customer submits the order you post the data to your server, determine which type of payment method the customer selected, then call the corresponding method in your PaymentHandlingService:
</p>

<pre>
  <code class="javascript">
    // PlaceOrderController.js
    var PlaceOrderController.js = module.exports = {
      execute: function () {
        if(request.method.methodType === "CREDIT_CARD") {
          PaymentHandlingService.chargeCreditCard(request.method);
        } else if() { // charge other types }
      };
    };

    // PaymentHandlingService.js
    var PaymentHandlingService = module.exports = {
      chargePayPal: function (paypalInstrument) {
        // force user to login to paypal
        // do something with the response from paypal
        return "charge paypal";
      },
      chargeCreditCard: function (cardInstrument) {
        // send to cc authority via secure form
        // do something with the response from cc authority
        return "charge cc";
      }
    };
  </code>
</pre>

<p>
  The problem with this implementation is two-fold. First, your API endpoint has to understand the concept of a PaymentMethod type in order to call the correct PaymentHandlingService function. We could put the type determination logic inside the PaymentHandlingService, but it's still tightly coupled to the PaymentMethod implementation. Second, we need a new method in PaymentHandlingService for each payment method we integrate with. After for or five payment method integrations, our service bloats with code specific to the different integration.
</p>

<p>
  Instead, we can treat PaymentMethods as individual Strategies under a PaymentInstrument class. The type determination logic can be moved to a PaymentMethodFactory that handles instantiation of our payment methods.
</p>

<pre>
  <code class="javascript">
    // PlaceOrderController.js
    var PlaceOrderController.js = module.exports = {
      execute: function () {
        return PaymentMethodFactory.create(request.method);
      };
    };

    // PaymentInstrument.js
    class PaymentInstrument {
      constructor(method) {
        this.method = method;
      };

      setMethod(method) {
        this.method = method;
      };
    };

    module.exports = PaymentInstrument;

    // PaymentMethodFactory.js
    class PaymentMethodFactory {
      create(method) {
        if(method.methodType === "CREDIT_CARD") {
          return new CreditCard(method);
        } else if(method.methodType === "PAYPAL") {
          return new Paypal(method);
        }
      }
    };

    // CreditCard.js
    class CreditCard {
      constructor(number, name, exp_month, exp_year, cvv) {
        this.number = number;
        this.name = name;
        this.exp_month = exp_month;
        this.cvv = cvv;
      };

      charge() {
        // send to cc authority via secure form
        // do something with the response from cc authority
        return "charge cc";
      }
    };

    module.exports.CreditCard = CreditCard;

    // Paypal.js
    class PayPal {
      constructor() {};

      charge() {
        // force user to login to paypal
        // do something with the response from paypal
        return "charge paypal";
      }
    };

    module.exports.PayPal = PayPal;
  </code>
</pre>

<p>
  Now our API endpoint is ambivalent towards the type of payment method in use. The domain logic required to charge individual payment methods is encapsulated inside simple, testable classes. Now our PaymentHandlingService can be scaled down:
</p>

<pre>
  <code type="text/javascript">
    // PaymentHandlingService.js
    var PaymentHandlingService = module.exports = {
      charge: function (instrument) {
        return instrument.charge();
      }
    }
  </code>
</pre>

<p>
  Now, none of our application outside the PaymentMethod classes and the PaymentMethodFactory know or care about individual payment method types. The complex logic for the different types is encapsulated within our PaymentMethod class with a clear, testable seam between the PaymentInstrument. If we need to create a new PaymentMethod, we can do some UI changes, a new Class and a few lines in our factory.
</p>

<pre>
  <code type="text/javascript">
    class NewHotPaymentMethod {
      constructor(param1, param2) {
        this.param1 = param1;
        this.param2 = param2;
      };

      charge() {
        return "charge new hot payment method";
      }
    };

    module.exports.NewHotPaymentMethod = NewHotPaymentMethod;
  </code>
</pre>

<p>
  Because our PaymentInstrument class holds a loose reference to a payment method, we're now able to swap out PaymentMethods on fly without affecting the state of our instrument.
</p>

<pre>
  <code type="text/javascript">
    var paymentInstrument = new PaymentInstrument();

    // customer fills out Credit Card form
    var creditCard = new PaymentMethod.CreditCard("4111111111111111", "Tester", "01", "2020", "123");
    paymentInstrument.setMethod(creditCard);

    // customer switches to PayPal
    var paypal = new PaymentMethod.PayPal();
    paymentInstrument.setMethod(paypal);

    paymentInstrument.charge(); // paypal
  </code>
</pre>

<p>
  Although this is a simplified explanation, hopefully you can see the benefits in the application of this pattern. I hope you find this helpful.
</p>

<p>
  I hope you've found this information useful. If you have any questions or concerns please feel free to follow me on Twitter.
</p>