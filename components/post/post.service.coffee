PostService = ($http, $timeout) ->
  timer = null
  handleResponse = (response) -> return response.data

  list: (page = 1) -> $http.get('/v1/post?page=' + page).then handleResponse
  listByKeyword: (keyword) -> $http.get('/v1/post/keyword/' + keyword).then handleResponse

  search: (q) ->
    if timer? then $timeout.cancel(timer)
    timer = $timeout ->
      $http.get('/v1/post/title?q=' + q).then(handleResponse)
    , 350


PostService.$inject = [ '$http', '$timeout' ]


angular
  .module 'app.post'
  .factory 'PostService', PostService