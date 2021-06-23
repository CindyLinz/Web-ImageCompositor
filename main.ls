Vue.create-app do
  data: ->
    width0: \1024
    gap0: \1
    border0: \1
    layout: '[3, [2, 3], 1]'
    queue: []
    ready: no
    background: ''
    download-url: ''
    height: 0

  computed:
    width: -> @width0 - 0
    gap: -> @gap0 - 0
    border: -> @border0 - 0

    layout-dimension: ->
      layout = try
        JSON.parse @layout
      catch
        []

      count-size = (layout) ->
        leave-n = 0
        branch-n = 1
        if layout instanceof Array
          for elem in layout
            res = count-size elem
            leave-n += res.leave-n
            branch-n += res.branch-n
        else
          leave-n += layout
        return {branch-n, leave-n}
      {branch-n, leave-n} = count-size layout

      build-matrix = (layout, dir, branch-i, leave-i) ~>
        matrix = [{}]
        if dir # v
          matrix.0 <<< "branch-h-#branch-i": -1
        else #h
          matrix.0 <<< "branch-w-#branch-i": -1

        if layout instanceof Array
          matrix.0 <<< constant: @gap * (layout.length - 1)
          sub-dir = 1 - dir
          self-branch-i = branch-i
          ++branch-i
          for elem in layout
            res = build-matrix elem, sub-dir, branch-i, leave-i
            if dir # v
              matrix.0["branch-h-#branch-i"] = 1
              matrix.push {"branch-w-#self-branch-i": -1, "branch-w-#branch-i": 1}
            else # h
              matrix.0["branch-w-#branch-i"] = 1
              matrix.push {"branch-h-#self-branch-i": -1, "branch-h-#branch-i": 1}
            matrix.push ...res.matrix
            {branch-i, leave-i} = res
        else
          matrix.0 <<< constant: @gap * (layout - 1)
          if dir # v
            for i from 0 til layout
              matrix.0["leave-h-#{leave-i + i}"] = 1
              matrix.push {"branch-w-#branch-i": -1, "leave-w-#{leave-i + i}": 1}
          else # h
            for i from 0 til layout
              matrix.0["leave-w-#{leave-i + i}"] = 1
              matrix.push {"branch-h-#branch-i": -1, "leave-h-#{leave-i + i}": 1}
          leave-i += layout
          ++branch-i
        return {matrix, branch-i, leave-i}

      {matrix} = build-matrix layout, 0, 0, 0
      for i from 0 til leave-n
        if @queue[i]?
          matrix.push {"leave-w-#i": -that.h, "leave-h-#i": that.w}
        else
          matrix.push {"leave-w-#i": -1, "leave-h-#i": 1}
      matrix.push {"branch-w-0": -1, constant: @width - 2 * @border}

      q-vectors = []
      r-columns = []

      field-list = [ [["leave-w-#x", "leave-h-#x"] for x from 0 til leave-n] , [["branch-w-#x", "branch-h-#x"] for x from 0 til branch-n] ].flat 2
      for field,i in field-list

        column = for row in matrix
          row[field] ? 0

        for qv,j in q-vectors
          dot = 0
          for k from 0 til qv.length
            dot += column[k + j] * qv[k]
          dot += dot
          for k from 0 til qv.length
            column[k + j] -= dot * qv[k]

        a2 = 0
        for j from 0 til field-list.length - i
          x = column[i + j]
          a2 += x * x
        a = Math.sqrt a2
        if column[i]>=0
          a = -a

        b = Math.sqrt 2 * (a2 - a * column[i])
        column[i] -= a

        q-vectors.push(qv = new Array(field-list.length - i))
        for j from 0 til field-list.length - i
          qv[j] = column[i + j] / b
        r-columns.push(rc = new Array(i + 1))
        for j from 0 til i
          rc[j] = column[j]
        rc[i] = a

      c-column = for row in matrix
        -(row.constant ? 0)
      for qv,i in q-vectors
        dot = 0
        for j from 0 til qv.length
          dot += c-column[i + j] * qv[j]
        dot += dot
        for j from 0 til qv.length
          c-column[i + j] -= dot * qv[j]

      res = {}
      for i from field-list.length - 1 to 0 by -1
        f = field-list[i]
        c = c-column[i]
        for j from i + 1 til field-list.length
          c -= c-column[j] * r-columns[j][i]
        res[f] = c-column[i] = c / r-columns[i][i]

      return res

    drawed: !->
      if !@ready || !@$refs.canvas
        @download-url = ''
        @height = 0
        return \Waiting

      dim = @layout-dimension

      canvas = @$refs.canvas
        ..width = dim["branch-w-0"] + @border * 2
        ..height = dim["branch-h-0"] + @border * 2

      @height = canvas.height
      if canvas.width <= 0 || canvas.height <= 0
        @download-url = ''
        return \Empty

      ctx = canvas.get-context \2d
      if @background == /\S/
        ctx.fill-style = @background
        ctx.fill-rect 0, 0, canvas.width, canvas.height

      layout = try
        JSON.parse @layout
      catch
        []

      draw = (layout, dir, branch-i, leave-i, x, y) ~>
        if layout instanceof Array
          sub-dir = 1 - dir
          for elem in layout
            ++branch-i
            res = draw elem, sub-dir, branch-i, leave-i, x, y
            if dir # v
              y += dim["branch-h-#branch-i"] + @gap
            else # h
              x += dim["branch-w-#branch-i"] + @gap
            {branch-i, leave-i} = res
        else
          for i from 0 til layout
            w = dim["leave-w-#leave-i"]
            h = dim["leave-h-#leave-i"]
            if w>0 && h>0
              if @queue[leave-i]?
                img = new Image
                  ..src = that.src
                ctx.draw-image img, x, y, w, h
              else
                ctx.fill-style = \#999
                ctx.fill-rect x, y, w, h
              if dir # v
                y += h + @gap
              else # h
                x += w + @gap

            ++leave-i
        return {branch-i, leave-i}
      draw layout, 0, 0, 0, @border, @border

      canvas.to-blob (blob) !~>
        @download-url = URL.create-objectURL blob
      return 'Done ' + Math.random!

  methods:
    remove: (i) !->
      @queue.splice i, 1

    left: (i) !->
      @queue[i - 1, i] = @queue[i, i - 1]
    right: (i) !->
      @queue[i + 1, i] = @queue[i, i + 1]

    select-file: !->
      file = it.target.files.0
      if file && file.type == /^image\//
        new Image
          ..src = URL.create-objectURL file
          ..onload = !~>
            @queue.push do
              src: ..src
              w: ..natural-width
              h: ..natural-height
        it.target.value = ''

  mounted: !->
    @ready = yes

.mount \#body
