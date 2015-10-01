require! \assert
{add} = require \./calculator

describe "", ->

    specify "must add 2 numbers", ->
        assert.equal (add 1, 2), 3