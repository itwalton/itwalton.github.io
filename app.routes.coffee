RouterConfig = ($stateProvider, $urlRouterProvider, $locationProvider) ->
  $urlRouterProvider.otherwise '/'
  $locationProvider.html5Mode true

  $stateProvider
    .state 'about',
      url: '/about'
      templateUrl: '/public/views/about.html'

    .state 'list',
      url: '/'
      controller: 'PostController'
      controllerAs: 'pc'
      templateUrl: '/app/components/post/list.html'
      resolve:
        post: -> return {}
        listData: Array 'PostService', (PostService) ->
          PostService.list()

    .state 'show',
      templateUrl: 'app/components/post/show.html'

    .state 'show.post',
      url: '/:template',
      templateUrl: ($stateParams) -> return '/public/posts/' + $stateParams.template + '.html'
      onEnter: Array '$timeout', ($timeout) ->
        $timeout ->
          hljs.initHighlighting.called = false
          hljs.initHighlighting()
        , 1

    .state 'search',
      url: '/keywords/:keyword'
      templateUrl: '/app/components/post/list.html'
      controller: 'PostController'
      controllerAs: 'pc'
      resolve:
        post: -> return {}
        listData: Array 'PostService', '$stateParams', (PostService, $stateParams) ->
          PostService.listByKeyword($stateParams.keyword)

RouterConfig.$inject = [ '$stateProvider', '$urlRouterProvider', '$locationProvider' ]


angular
  .module 'mainApp'
  .config RouterConfig