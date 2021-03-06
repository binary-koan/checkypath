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
      return JSON.parse(localStorage.getItem("TestThings_paths")) || []
    },
    get badPages() {
      return JSON.parse(localStorage.getItem("TestThings_badPages")) || []
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
      badPages: state.badPages,
      currentIndex: state.currentIndex,
      currentPath: state.paths[state.currentIndex]
    }
  }

  // State setters
  function setBaseUrl(url) {
    localStorage.setItem("TestThings_baseUrl", url)
  }

  function loadPaths(content) {
    if (content != state.originalPaths) {
      localStorage.setItem("TestThings_originalPaths", content)

      const paths = content.split("\n").filter(path => !/^\s*$/.test(path) && !path.startsWith("#"))
      localStorage.setItem("TestThings_paths", JSON.stringify(paths))
      localStorage.setItem("TestThings_badPages", JSON.stringify([]))
    }
  }

  function setCurrentIndex(index) {
    if (index == undefined) {
      document.location.hash = ""
    } else {
      document.location.hash = `?currentIndex=${index}`
    }
  }

  function markBadPage(message) {
    const path = state.paths[state.currentIndex]

    if (path) {
      const badPages = state.badPages
      badPages[state.currentIndex] = { path, message }
      localStorage.setItem("TestThings_badPages", JSON.stringify(badPages))
    }
  }

  function markGoodPage() {
    if (state.paths[state.currentIndex]) {
      const badPages = state.badPages
      badPages[state.currentIndex] = null
      localStorage.setItem("TestThings_badPages", JSON.stringify(badPages))
    }
  }

  function goNext() {
    const { currentIndex, paths } = state

    if (!paths.length) return

    if (currentIndex == undefined) {
      setCurrentIndex(0)
    } else if (currentIndex < paths.length) {
      setCurrentIndex(currentIndex + 1)
    }
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

    goNext: action("goNext", goNext),

    goPrevious: action("goPrevious", () => {
      const { currentIndex, paths } = state

      if (!paths.length) return

      if (currentIndex != undefined && currentIndex > 0) {
        setCurrentIndex(currentIndex - 1)
      } else if (currentIndex === 0) {
        setCurrentIndex(undefined)
      }
    }),

    markGoodAndGoNext: action("markGoodAndGoNext", () => {
      markGoodPage()
      goNext()
    }),

    markBadAndGoNext: action("markBadAndGoNext", message => {
      markBadPage(message)
      goNext()
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

function updateBadPageDetails(state) {
  const badPage = state.badPages[state.currentIndex]

  if (badPage) {
    document.querySelector("#bad-message").value = badPage.message
  } else {
    document.querySelector("#bad-message").value = ""
  }
}

function updateBadPagesSummary(state) {
  const badPageDetails = state.badPages.filter(Boolean).map(({ path, message }) =>
    `# ${message || "(This page doesn't look right)"}\n${path}\n`
  )

  document.querySelector("#bad-pages-summary").value = badPageDetails.join("\n")

  if (badPageDetails.length) {
    document.querySelectorAll(".if-any-bad-pages").forEach(el => el.classList.remove("hidden"))
    document.querySelectorAll(".if-no-bad-pages").forEach(el => el.classList.add("hidden"))
  } else {
    document.querySelectorAll(".if-any-bad-pages").forEach(el => el.classList.add("hidden"))
    document.querySelectorAll(".if-no-bad-pages").forEach(el => el.classList.remove("hidden"))
  }
}

store.subscribe(state => {
  updateCurrentPage(state)
  updateSetupYayness(state)
  updatePathCounts(state)
  updatePathAndBaseUrl(state)
  updateIframeSrc(state)
  updateBadPageDetails(state)
  updateBadPagesSummary(state)

  document.querySelector("#paths").value = state.originalPaths || ""
  document.querySelector("#base-url").value = state.baseUrl || ""
})

// Events
document.querySelectorAll(".action-next").forEach(el => {
  el.addEventListener("click", () => store.markGoodAndGoNext())
})

document.querySelector(".action-next-bad").addEventListener("click", () => {
  store.markBadAndGoNext(document.querySelector("#bad-message").value)
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
