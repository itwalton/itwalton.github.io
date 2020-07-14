---
layout: post
date: 2020-07-13
title: Better Dependency Management in Express Applications
header: Better Dependency Management in Express Applications
description: Leverage TypeScript with dependency injection for cleaner, more maintainable REST APIs.
---

The Node/Express stack is great, but managing dependencies can quite painful. Usually reusing service connections, singletons, or other dependencies end up in a hodgepodge of import statements and frankensteined request objects. This can lead to unnecessary overhead per request and/or runtime exceptions. I want to share a pattern that I've found helpful when building maintainable RESTful interfaces.

Service connections, like to MongoDB or Redis, are expensive to instantiate and are often intended to be long-lived. Certainly we don't want to overhead of restablishing the connection each time a request is made. Instead we frontload expensive operations at the application startup sequence, wherein if a failure occurs we can terminate quickly & let the control plane (Kubernetes, ECS Fargate, etc.) dictate where and when to try again. We end up with server & type files that looks something like:

~~~ javascript
// types.ts
import { Request } from 'express';
import { MongoClient } from 'mongodb';

export interface BaseRequest implements Request {
    locals: {
        mongoClient: MongoClient;
    }
}

// server.ts
import express from 'express';
import { MongoClient } from 'mongodb';

import { BaseRequest } from './types';
import AppRouter from './app/app.router';

export const start = async () => {
    const mongoClient = await MongoClient.connect({ url: process.env.MONGO_URL });
    const app = express();

    app.use((req: BaseRequest, res, next) => {
        req.locals.mongoClient = mongoClient;
    });

    app.use('/', AppRouter);
    app.listen(process.env.PORT);

    return app;
}
~~~

In this manner we ensure the connection pool is established immediately, otherwise we let the library through an exception caught wherever start is called.

While this is a great start, any routes using this client will have an implicit dependency on req.locals.mongoClient. What happens if we add middleware before we pass mongoClient? Instead, we let each route dictate it's parameters explicitly.

~~~ javascript
    import { MongoClient } from 'mongodb';
    import { BaseRequest } from '../types';

    // app/routes/list.route.ts
    export const list = (mongoClient: MongoClient) => (req: BaseRequest, res, next) => {
        ...
    }

    // app/routes/index.ts
    import { list } from './list.route';
    export default { list };

    // app/index.ts
    export { default as AppRoutes } from './routes';

    // server.ts
    import { AppRoutes } from './app';
    ...

    app.use('/', express.Router()
        .get('/', AppRoutes.list(mongoClient))
    );

    ...
~~~

Our server file becomes the single source of truth for what routes are implemented by our application & what each dependency needs. We've leaned into the power of TypeScript to handle compilation errors when a dependency is missing from a routes' method signature.

I hope you enjoyed the article! Still shaking off the rust. Look for more articles coming soon! If you have any questions/comments/concerns, as always, feel free to follow me on Twitter.
