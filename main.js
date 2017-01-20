// Hacky Redux-like global store
const store = (() => {
  // State getters
  const state = {
    get baseUrl() {
      return localStorage.getItem("TestThings_baseUrl")
    },
    get originalPaths() {
      return localStorage.getItem("TestThings_originalPaths")
    },
    get paths() {
      return JSON.parse(localStorage.getItem("TestThings_paths"))
    },
    get currentIndex() {
      const match = document.location.hash.match(/(?:\?|&)currentIndex=(\d+)/)
      return match && parseInt(match[1])
    }
  }

  function resolveState() {
    return {
      baseUrl: state.baseUrl,
      originalPaths: state.originalPaths,
      paths: state.paths,
      currentIndex: state.currentIndex,
      currentPath: state.paths[state.currentIndex]
    }
  }

  // State setters
  function setBaseUrl(url) {
    localStorage.setItem("TestThings_baseUrl", url)
  }

  function loadPaths(content) {
    localStorage.setItem("TestThings_originalPaths", content)

    const paths = content.split("\n").filter(path => !/^\s*$/.test(path) && !path.startsWith("#"))
    localStorage.setItem("TestThings_paths", JSON.stringify(paths))
  }

  function setCurrentIndex(index) {
    if (index == undefined) {
      document.location.hash = ""
    } else {
      document.location.hash = `?currentIndex=${index}`
    }

    //TODO test this
  }

  // Action boilerplate
  const changeListeners = []

  function action(name, handler) {
    return data => {
      console.log(`Action: ${name}`, data)
      handler(data)
      changeListeners.forEach(listener => listener(resolveState()))
    }
  }

  // Public actions
  const actions = {
    setBaseUrl: action("setBaseUrl", setBaseUrl),

    loadPaths: action("loadPaths", loadPaths),

    goNext: action("goNext", () => {
      const { currentIndex, paths } = state

      if (!paths.length) return

      if (currentIndex == undefined) {
        setCurrentIndex(0)
      } else if (currentIndex < paths.length) {
        setCurrentIndex(currentIndex + 1)
      }
    }),

    goPrevious: action("goPrevious", () => {
      const { currentIndex, paths } = state

      if (!paths.length) return

      if (currentIndex != undefined && currentIndex > 0) {
        setCurrentIndex(currentIndex - 1)
      }
    }),

    reset: action("reset", () => {
      setCurrentIndex(undefined)
    })
  }

  return Object.assign({
    state,
    subscribe(listener) {
      changeListeners.push(listener)
      listener(resolveState())
    }
  }, actions)
})()

// View update logic
function updateCurrentPage(state) {
  document.querySelectorAll(".page").forEach(page => page.classList.add("hidden"))

  if (state.currentPath) {
    document.querySelector("#in-progress").classList.remove("hidden")
  } else if (state.paths && state.currentIndex == state.paths.length) {
    document.querySelector("#finished").classList.remove("hidden")
  } else {
    document.querySelector("#setup").classList.remove("hidden")
  }
}

function updateSetupYayness(state) {
  if (state.paths && state.paths.length) {
    document.querySelector("#setup").classList.add("not-yay")
  } else {
    document.querySelector("#setup").classList.remove("not-yay")
  }
}

function updatePathCounts(state) {
  if (state.paths && state.paths.length) {
    document.querySelector("#start").innerHTML = `Start (${state.paths.length}) →`

    if (state.currentPath) {
      document.querySelector(".paths-count").innerHTML = `${state.currentIndex + 1}/${state.paths.length}`
    }
  } else {
    document.querySelector("#start").innerHTML = `Start →`
  }
}

function updatePathAndBaseUrl(state) {
  if (state.currentPath) {
    document.querySelector(".path-and-baseurl .path").innerHTML = state.currentPath
  }

  document.querySelector(".path-and-baseurl .baseurl").innerHTML = state.baseUrl
}

function updateIframeSrc(state) {
  if (state.currentPath) {
    const url = state.baseUrl + state.currentPath

    if (document.querySelector("iframe").src != url) {
      document.querySelector("iframe").src = url
      document.querySelector(".loader").classList.remove("done")
    }
  }
}

store.subscribe(state => {
  updateCurrentPage(state)
  updateSetupYayness(state)
  updatePathCounts(state)
  updatePathAndBaseUrl(state)
  updateIframeSrc(state)

  document.querySelector("#paths").value = state.originalPaths || ""
  document.querySelector("#base-url").value = state.baseUrl || ""
})

// Events
document.querySelectorAll(".action-next").forEach(el => {
  el.addEventListener("click", () => store.goNext())
})

document.querySelectorAll(".action-previous").forEach(el => {
  el.addEventListener("click", () => store.goPrevious())
})

document.querySelectorAll(".action-restart").forEach(el => {
  el.addEventListener("click", () => store.reset())
})

document.querySelector("#paths").addEventListener("change", e => {
  store.loadPaths(e.target.value)
})

document.querySelector("#base-url").addEventListener("change", e => {
  store.setBaseUrl(e.target.value)
})

document.querySelector("iframe").addEventListener("load", () => {
  document.querySelector(".loader").classList.add("done")
})
