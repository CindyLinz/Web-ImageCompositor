Vue.create-app do
  data: ->
    width0: \1024
    gap0: \1
    border0: \1
    radius0: \0
    layout: '[3, [2, 3], 1]'
    queue: []
    hit-box: []
    ready: no
    background: ''
    download-url: ''
    height: 0
    select-cursor: void
    cropping: void
    zoom-step: 0.2

    splitting: -1
    splitting-num: 2
    splitting-dir: \h

  computed:
    width: -> @width0 - 0
    gap: -> @gap0 - 0
    radius: -> @radius0 - 0
    border: -> if @radius > 0 then @border0 - 0 + 1 else @border0 - 0

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
          q = that
          if q.crop?
            if q.r % 2 == 0
              matrix.push {"leave-w-#i": -q.crop.h, "leave-h-#i": q.crop.w}
            else
              matrix.push {"leave-w-#i": -q.crop.w, "leave-h-#i": q.crop.h}
          else
            matrix.push {"leave-w-#i": -q.h, "leave-h-#i": q.w}
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
        ..width = @width
        ..height = dim["branch-h-0"] + @border * 2

      @height = canvas.height
      if @width <= 0 || @height <= 0
        @download-url = ''
        return \Empty

      ctx = canvas.get-context \2d

      if @radius > 0
        ctx.begin-path!
        ctx.move-to 1, @radius + 1
        ctx.arc-to 1, 1, @radius + 1, 1, @radius
        ctx.line-to @width - @radius - 1, 1
        ctx.arc-to @width - 1, 1, @width - 1, @radius + 1, @radius
        ctx.line-to @width - 1, @height - @radius - 1
        ctx.arc-to @width - 1, @height - 1, @width - @radius - 1, @height - 1, @radius
        ctx.line-to @radius + 1, @height - 1
        ctx.arc-to 1, @height - 1, 1, @height - @radius - 1, @radius
        ctx.close-path!
        ctx.clip!

      if @background == /\S/
        ctx.fill-style = @background
        ctx.fill-rect 0, 0, @width, canvas.height

      if @radius > @border
        ctx.begin-path!
        ctx.move-to @border, @radius + 1
        ctx.arc-to @border, @border, @radius + 1, @border, @radius - @border
        ctx.line-to @width - @radius, @border
        ctx.arc-to @width - @border, @border, @width - @border, @radius + 1, @radius - @border
        ctx.line-to @width - @border, @height - @radius
        ctx.arc-to @width - @border, @height - @border, @width - @radius, @height - @border, @radius - @border
        ctx.line-to @radius + 1, @height - @border
        ctx.arc-to @border, @height - @border, @border, @height - @radius, @radius - @border
        ctx.close-path!
        ctx.clip!

      layout = try
        JSON.parse @layout
      catch
        []

      @hit-box = []

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
                q = that
                  ..img
                if q.crop
                  cx = that.x
                  cy = that.y
                  W = that.w
                  H = that.h
                else
                  cx = 0
                  cy = 0
                  W = q.img.natural-width
                  H = q.img.natural-height

                ctx.save!

                if q.f
                  switch q.r
                  | 0 =>
                    # [1 0 x+w][-1 0][w/W 0 ][1 0 -cx] = [-w/W 0  x+w+cx*w/W]
                    # [0 1  y ][ 0 1][ 0 h/H][0 1 -cy] = [  0 h/H  y-cy*h/H ]
                    ctx.set-transform -w/W, 0, 0, h/H, x+w + cx*w/W, y - cy*h/H
                  | 1 =>
                    # [1 0 x][-1 0][0 -1][w/H 0 ][1 0 -cx] = [ 0 h/W x-cy*h/W]
                    # [0 1 y][ 0 1][1  0][ 0 h/W][0 1 -cy] = [w/H 0  y-cx*w/H]
                    ctx.set-transform 0, w/H, h/W, 0, x - cy*h/W, y - cx*w/H
                  | 2 =>
                    # [1 0  x ][-1 0][-1 0][w/W 0 ][1 0 -cx] = [w/W  0   x-cx*w/W]
                    # [0 1 y+h][ 0 1][0 -1][ 0 h/H][0 1 -cy] = [ 0 -h/H y+h+cy*h/H]
                    ctx.set-transform w/W, 0, 0, -h/H, x - cx*w/W, y+h + cy*h/H
                  | 3 =>
                    # [1 0 x+w][-1 0][ 0 1][w/H 0 ][1 0 -cx] = [  0 -h/W x+w+cy*h/W]
                    # [0 1 y+h][ 0 1][-1 0][ 0 h/W][0 1 -cy] = [-w/H  0  y+h+cx*w/H]
                    ctx.set-transform 0, -w/H, -h/W, 0, x+w + cy*h/W, y+h + cx*w/H
                else
                  switch q.r
                  | 0 =>
                    # [1 0 x][w/W 0 ][1 0 -cx] = [w/W 0  -cx*w/W+x]
                    # [0 1 y][ 0 h/H][0 1 -cy] = [ 0 h/H -cy*h/H+y]
                    ctx.set-transform w/W, 0, 0, h/H, x - cx*w/W, y - cy*h/H
                  | 1 =>
                    # [1 0 x+w][0 -1][w/H 0 ][1 0 -cx] = [ 0 -h/W x+w+cx*h/W]
                    # [0 1  y ][1  0][ 0 h/W][0 1 -cy] = [w/H  0   y-cy*w/H ]
                    ctx.set-transform 0, w/H, -h/W, 0, x+w + cy*h/W, y - cx*w/H
                  | 2 =>
                    # [1 0 x+w][-1 0][w/W 0 ][1 0 -cx] = [-w/W  0  x+w+cx*w/W]
                    # [0 1 y+h][0 -1][ 0 h/H][0 1 -cy] = [  0 -h/H y+h+cy*h/H]
                    ctx.set-transform -w/W, 0, 0, -h/H, x+w + cx*w/W, y+h + cy*h/H
                  | 3 =>
                    # [1 0  x ][ 0 1][w/H 0 ][1 0 -cx] = [  0 h/W  x-cy*h/W ]
                    # [0 1 y+h][-1 0][ 0 h/W][0 1 -cy] = [-w/H 0  y+h+cx*w/H]
                    ctx.set-transform 0, -w/H, h/W, 0, x - cy*h/W, y+h + cx*w/H

                if q.crop
                  ctx.begin-path!
                  ctx.move-to that.x, that.y
                  ctx.line-to that.x+that.w, that.y
                  ctx.line-to that.x+that.w, that.y+that.h
                  ctx.line-to that.x, that.y+that.h
                  ctx.close-path!
                  ctx.clip!
                ctx.draw-image q.img, 0, 0

                ctx.restore!
              else
                ctx.fill-style = \#999
                ctx.fill-rect x, y, w, h
              @hit-box.push {x, y, w, h}
              if dir # v
                y += h + @gap
              else # h
                x += w + @gap

            ++leave-i
        return {branch-i, leave-i}
      draw layout, 0, 0, 0, @border, @border

      for i from @queue.length til @hit-box.length
        @queue.push void
      while @queue.length > @hit-box.length && !@queue[* - 1]
        @queue.pop!

      canvas.to-blob (blob) !~>
        @download-url = URL.create-objectURL blob
      return 'Done ' + Math.random!

  methods:
    remove: (i) !->
      @queue[i] = void
    rotate: (i) !->
      if @queue[i]
        q = that
        if q.f
          q.r = (q.r + 3) % 4
        else
          q.r = (q.r + 1) % 4
        [q.w, q.h] = [q.h, q.w]
        if q.f
          tr = <[-50%,50% 50%,50% 50%,-50% -50%,-50%]>
          q.transform = "translate(-50%,-50%)scaleX(-1)rotate(#{q.r*90}deg)scale(#{100/q.h})translate(#{tr[q.r]})"
        else
          tr = <[50%,50% 50%,-50% -50%,-50% -50%,50%]>
          q.transform = "translate(-50%,-50%)rotate(#{q.r*90}deg)scale(#{100/q.h})translate(#{tr[q.r]})"
    flip: (i) !->
      if @queue[i]
        q = that
        q.f = 1 - q.f
        if q.f
          tr = <[-50%,50% 50%,50% 50%,-50% -50%,-50%]>
          q.transform = "translate(-50%,-50%)scaleX(-1)rotate(#{q.r*90}deg)scale(#{100/q.h})translate(#{tr[q.r]})"
        else
          tr = <[50%,50% 50%,-50% -50%,-50% -50%,50%]>
          q.transform = "translate(-50%,-50%)rotate(#{q.r*90}deg)scale(#{100/q.h})translate(#{tr[q.r]})"
    crop: (i) !->
      if @cropping
        @cropping.handle?remove!

      if @queue[i]
        img = that
        @cropping = do
          i: i
          src: img.src
          W: img.w
          H: img.h
          zoom: 1 <? document.document-element.client-width / img.w * 0.9 <? document.document-element.client-height / img.h * 0.9
        if img.crop
          @cropping{x, y, w, h} = that{x, y, w, h}
          @cropping.active = yes
        else
          @cropping
            ..x = 0
            ..y = 0
            ..w = img.w
            ..h = img.h
            ..active = no
        set-timeout !~>
          @cropping-set 0
        , 0

    cropping-set: (active) !->
      @$refs.cropping-image.width = @cropping.W * @cropping.zoom
      @cropping.handle?remove!

      if active
        @cropping.active = yes

      @cropping.handle = crop_image @$refs.cropping-image, void, (dim) !~>
        @cropping.active = yes
        for f in <[x y w h]>
          @cropping[f] = dim[f] / @cropping.zoom
      if @cropping.active
        @cropping.handle.set_crop do
          x: @cropping.x * @cropping.zoom
          y: @cropping.y * @cropping.zoom
          w: @cropping.w * @cropping.zoom
          h: @cropping.h * @cropping.zoom

    cropping-cancel: !->
      @cropping.handle?remove!
      @cropping = void

    cropping-do: !->
      {x, y, w, h} = @cropping
      @queue[@cropping.i]
        ..crop = {x, y, w, h}
        ..clip = "rect(#{y}px,#{x+w}px,#{y+h}px,#{x}px)"
      @cropping.handle?remove!
      @cropping = void

    cropping-touch-start: !->
      console.warn \touch-start, it

      cropping = cropping0 = @cropping-touch ? []
      for t in it.changed-touches
        cropping = for c in cropping when c.id != t.identifier
          c
        cropping.push do
          id: t.identifier
          x: t.client-x
          y: t.client-y
      @cropping-touch = cropping

      if cropping0.length < 2 && cropping.length >= 2
        @cropping-touch-zoom = @cropping.zoom

    cropping-touch-move: !->
      console.warn \touch-move, it

      dis = (x1, y1, x2, y2) ->
        Math.sqrt (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)

      cropping = @cropping-touch ? []
      for t in it.changed-touches
        for c,i in cropping when c.id == t.identifier
          if i < 2
            c.x2 = t.client-x
            c.y2 = t.client-y
            if cropping.length >= 2
              dis1 = dis cropping.0.x, cropping.0.y, cropping.1.x, cropping.1.y
              dis2 = dis cropping.0.x2, cropping.0.y2, cropping.1.x2, cropping.1.y2
              if dis1 && dis2
                console.warn \touch, "(#{cropping.0.x},#{cropping.0.y}) (#{cropping.1.x},#{cropping.1.y})", "(#{cropping.0.x2},#{cropping.0.y2}) (#{cropping.1.x2},#{cropping.1.y2})"
                console.warn \zoom, dis1, dis2, dis2 / dis1
                @cropping.zoom = @cropping-touch-zoom * dis2 / dis1
          else
            c.x = t.client-x
            c.y = t.client-y

      @console.warn \@cropping, JSON.stringify cropping, cropping

      if cropping.length >= 2
        it.prevent-default!
        it.stop-propagation!

    cropping-touch-stop: !->
      console.warn \touch-stop, it

      cropping = @cropping-touch ? []
      for t in it.changed-touches
        cropping = for c in cropping when c.id != t.identifier
          c
      if cropping.length >=2 && (!cropping.0.x2? || !cropping.1.x2?)
        @cropping-touch-zoom = @cropping.zoom
        for c,i in cropping when i<2
          c.x2 = c.x
          c.y2 = c.y

      @cropping-touch = cropping

    split: (i) !->
      @splitting = i
    splitting-cancel: !->
      @splitting = -1
    splitting-split: !->
      @splitting-num = @splitting-num .|. 0
      if @splitting-num > 1
        for i from @splitting + 1 to @splitting + @splitting-num - 1
          @queue.splice i, 0, ^^@queue[@splitting]
        if @splitting-dir == \h
          if @queue[@splitting].crop
            x = that.x
            w = that.w / @splitting-num
            y = that.y
            h = that.h
          else
            x = 0
            w = @queue[@splitting].w / @splitting-num
            y = 0
            h = @queue[@splitting].h
          for i from @splitting to @splitting + @splitting-num - 1
            @queue[i].crop = {x, y, w, h}
            x += w
        else
          if @queue[@splitting].crop
            x = that.x
            w = that.w
            y = that.y
            h = that.h / @splitting-num
          else
            x = 0
            w = @queue[@splitting].w
            y = 0
            h = @queue[@splitting].h / @splitting-num
          for i from @splitting to @splitting + @splitting-num - 1
            @queue[i].crop = {x, y, w, h}
            y += h
      @splitting = -1;

    left: (i) !->
      @queue[i - 1, i] = @queue[i, i - 1]
    right: (i) !->
      @queue[i + 1, i] = @queue[i, i + 1]

    click-queue: (i) !->
        @select-cursor = i
        document.query-selector '[type=file]' .click!

    click-final: (ev) !->
      box = @$refs.canvas.get-bounding-client-rect!
      x = ev.x - box.x
      y = ev.y - box.y
      for b,i in @hit-box
        if b.x<=x && b.y<=y && x<b.x+b.w && y<b.y+b.h
          @select-cursor = i
          document.query-selector '[type=file]' .click!
          break

    select-file: !->
      for let file,i in it.target.files when file?type == /^image\//
        new Image
          ..src = URL.create-objectURL file
          ..onload = !~>
            w = ..natural-width
            h = ..natural-height
            if w > 0 && h > 0
              @queue[@select-cursor + i] = do
                img: ..
                src: ..src
                w: w
                h: h
                transform: "translate(-50%,-50%)scale(#{100/h})translate(50%,50%)"
                r: 0
                f: 0
                crop: void
                clip: void

      it.target.value = ''

  mounted: !->
    @ready = yes

.mount \#body
