# claylib
A Common Lisp 2D/3D game toolkit built on top of [Raylib](https://www.raylib.com/) 4.2.

## Quick Start
Claylib is not yet in Quicklisp. Load claylib.asd and run `(ql:quickload :claylib/examples)` or similar to load all of the available packages. See the next section for what those packages are and how you might use them.

To see the [examples](/examples) in action, just run e.g. `(claylib/examples/basic-window:main)`. Hit Escape to exit. At the time of this writing, most of the core examples are done, as well as a handful from other categories. GUI examples are very **work-in-progress**.

Tested only on Linux, so far. There's no obvious reason it can't work on other platforms, but you might need to build Raylib and Raygui yourself.

## Packages
This repo contains four separate ASDF systems:
- `claylib/wrap` wraps Raylib, Raymath, and Raygui via [cl-autowrap](https://github.com/rpav/cl-autowrap), along with a few small fixes. There's probably no reason to use it directly.
- `claylib/ll` is a thin layer on top of `claylib/wrap` that adds some convenience features but mostly keeps the C semantics. If you have a lot of experience with Raylib in C or you just really like manual memory management, then `claylib/ll` is for you.
- `claylib` sits atop `claylib/ll` and does a lot of work to try to smooth out and abstract the C semantics away from the user. It's not perfect, nor _can_ it be (more on that later). Its goal is to feel as Lispy as possible, and no Lispier!
- `claylib/examples` contains a number of -- you guessed it -- examples, remixed from [Raylib's own](https://www.raylib.com/examples.html).

## Current Status
The project should be considered **beta**. Development is active and API's are subject to change.

`claylib/ll` should be highly usable, as a thin wrapper over Raylib and Raymath. Raygui is sparsely tested but probably usable if you know what you're doing; Lispification and examples are in progress.

For `claylib`, you're best off reviewing the examples as a survey of what's done and what's not. 2D support is largely complete; 3D support is a bit more iffy. If any piece is particularly important to you, please file an [issue](https://github.com/defun-games/claylib/issues) and we will prioritize it!

## Using `claylib`
Walking through the [first texture example](/examples/textures/logo-raylib-texture.lisp) will give a "boilerplate" of how you might make a game with `claylib`. (This is certainly not the only way, just _a_ way.)

### `with-window`
```
(defun main ()
  (with-window (:title "raylib [textures] example - texture loading and drawing")
    ...))
```
The `with-window` macro initializes a new Raylib window and takes care of freeing stray C memory when it closes. Here we set the window title with the `:title` keyword. Other keywords:
- `:width` -- window width in pixels, an integer
- `:height` -- window height in pixels, an integer
- `:fps` -- target frames-per-second, an integer
- `:flags` -- a list of window flag constants (of the form `+flag-whatever+`)
- `:min-size` -- the minimum window size, a two-element list `(width height)`

### Scenes
```
(let* ((image-size 256)
       (scene (make-scene ((texass (make-texture-asset ...)))
                          ((texture (make-texture texass ...))
                           (text (make-text ...))))))
  ...)
```
"Scenes" are a new concept in Claylib that don't really exist in Raylib. Scenes aim to make it easier to create groups of objects and assets, and allocate your memory up front wherever possible. Using scenes well will also maximize REPL interactivity while you develop your game; more on this in the `do-game-loop` section below. `make-scene` takes two lists -- a list of game **assets** and a list of game **objects**.

**Assets** are where you load your models, textures, audio, etc. from files. You'll use these pre-loaded assets later, as components of this scene's game objects, background music, and so on. When defining an asset, you specify a path and can either pass `:load-now t` to load it immediately, or let `with-scenes` do it automatically later on. Important note: Modifying an asset will modify all objects composed of that asset! This is usually discouraged.

**Objects**, in a nutshell, are things that get drawn on the screen. Technically you can put things in here that can't be drawn, but there probably aren't many reasons to, and it could break your draw loop if you aren't careful. Sometimes you'll want to compose objects from an already defined asset, such as via `make-texture`.

Under the hood, `make-scene` is a macro that includes a `let*` so you can reference previous bindings within the same definition. (This does mean, however, that the assets and objects share a namespace and must all have unique names.) In this case, `scene` will contain two game objects named `text` and `texture`, with the latter being formed from the asset `texass`. There is also a `:gc` keyword, a boolean that toggles garbage collection when the scene closes out. This is `t` by default.

### `make-whatever`
```
(make-texture-asset
 (claylib/examples:claylib-path
  "examples/textures/resources/raylib_logo.png"))
(make-texture texass
              (/ (- (get-screen-width) image-size) 2.0)
              (/ (- (get-screen-height) image-size) 2.0))
(make-text "this IS a texture!"
            360 370
            :size 10
            :color +gray+)
```
As mentioned above, `make-texture-asset` takes a required pathname and a `:load-now` keyword argument.

`make-texture` requires a `texture-asset`, and X and Y coordinates for where the texture should be drawn. The drawing can be modified via a number of keyword arguments: `:width`, `:height`, `:tint`, etc. (Most fall under the category of "you'll know them if you need them.")

`make-text` takes three required arguments -- a text string, and the X and Y coordinates where the text should be drawn. In practice you'll frequently pass `:size` and `:color` but they do have sane defaults for the lazy, as does `:spacing`. You can also pass your own `font` object via `:font`... but let's not get ahead of ourselves.

`claylib` exports a number of `make-whatever` functions for these game objects, which you are recommended to use where available. Not every class has such a corresponding function yet.

### `with-scenes`
```
(with-scenes scene ()
  ...)
```
The `with-scenes` macro takes a single scene or a list of scenes; for each scene it loads your assets if you passed any and prepares your game objects. In the parens you can pass a `:gc` argument, which will either force or disable garbage collection at the end of the body regardless of scene-specific settings. If `:gc` is not passed, the scene setting is used (i.e. GC will run if at least one scene requests it).

### `do-game-loop`
```
(do-game-loop (:livesupport t)
  ...)
```
The `do-game-loop` macro is your main loop, where your game will spend most of its time and where performance and consing matter the most. It's just a fancy `do` form, so you can pass corresponding `:vars`, `:end`, and `:result` keywords. The end form has an implied `(or (window-should-close-p) ...)` which means the loop will always terminate when you hit Escape, in addition to whatever conditions you pass.

As for `:livesupport`: `claylib` uses the excellent [livesupport](https://github.com/cbaggers/livesupport) library to provide better interactive development. With it enabled, you can run your game and see your changes at the REPL reflected in real-time. This is where scenes come in, as all you need to do is `setf` a scene object's properties and watch that object be drawn differently. Any functions that are called from your game loop can be similarly live-modified. It is recommended to keep `:livesupport` enabled for development and disable it when you ship your game.

### `with-drawing`
```
(with-drawing () ...)
```
A simple macro that encloses the body in a drawing mode. By default it clears the `*claylib-background*` color at the beginning, or you can pass :bgcolor in the parens to clear a different one. Other similar macros:
- `with-2d-mode`
- `with-3d-mode`
- `with-texture-mode`
- `with-scissor-mode`

### `draw-scene-*`
```
(draw-scene-all scene)
```
Draw every game object in the passed scene, _in the order those objects were put into the scene_. For greater specificity, use one of the other functions:
- `draw-scene`
- `draw-scene-except`
- `draw-scene-regex`
