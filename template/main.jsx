import React from "react";
import { createRoot } from "react-dom/client";
import { useEffect, useState } from "react";

import Prism from "prismjs";

import "prismjs/themes/prism-okaidia.css";
import "prismjs/components/prism-zig";

function FunctionComponentView({
  main_package_name,
  function_obj,
  file_name,
  onBack,
}) {
  useEffect(() => {
    Prism.highlightAll();
  }, [function_obj]);

  return (
    <>
      <h1>Package {main_package_name}</h1>
      <hr className="main_hr" />

      <button onClick={onBack}>Back</button>
      <h2>
        Function <span style={{ color: "#0e7496" }}>{function_obj.name}</span>
        &nbsp;<a href="#">[src]</a>
      </h2>

      <article className="card">
        <header>
          <h3>
            File <span style={{ color: "#0e7496" }}>{file_name}</span>:
            <span style={{ color: "#0e7496" }}>{function_obj.line_number}</span>
          </h3>
        </header>
        <footer>
          <pre>
            <code className="language-zig">
              {(function_obj.signature ?? "").trim()}
            </code>
          </pre>
        </footer>
      </article>

      {function_obj.comment && (
        <article className="card">
          <header>
            <h3>Comment</h3>
          </header>
          <footer>
            {function_obj.comment}
          </footer>
        </article>
      )}
    </>
  );
}

function HomeComponent({
  main_package_name,
  documentation,
  setSelectedFunction,
  setShowNormalView,
}) {
  return (
    <>
      <h1>Package {main_package_name}</h1>

      <hr className="main_hr" />

      <article class="card">
        <header>
          <h3>Documentation</h3>
        </header>
        <footer></footer>
      </article>

      <article class="card">
        <header>
          <h3>Functions</h3>
        </header>
        <footer>
          {documentation.map(([file_name, file_data]) =>
            file_data.map((x, index) => (
              <React.Fragment key={`${file_name}-${index}`}>
                {x.type === "function" && (
                  <>
                    <a
                      href="#"
                      className="function_name"
                      onClick={(e) => {
                        e.preventDefault();
                        setSelectedFunction({
                          function_obj: x,
                          file_name,
                        });
                        setShowNormalView(false);
                      }}
                    >
                      {x.name}
                    </a>
                    <br />
                  </>
                )}
              </React.Fragment>
            )),
          )}
        </footer>
      </article>

      <article class="card">
        <header>
          <h3>Tests</h3>
        </header>
        <footer>
          {documentation.map(([file_name, file_data]) =>
            file_data.map((x, index) => (
              <React.Fragment key={`test-${file_name}-${index}`}>
                {x.type === "test" && (
                  <>
                    <a href="#" className="function_name">
                      {x.name}
                    </a>
                    <br />
                  </>
                )}
              </React.Fragment>
            )),
          )}
        </footer>
      </article>
    </>
  );
}

function Navbar() {
  return (
    <>
      <article class="card navbar">
        <header class="two">
          <h2>ZigRef</h2>
          <h5>By Zigistry</h5>
        </header>
      </article>
    </>
  );
}

function App() {
  const main_package_name = "gh/zigistry/zigistry";

  const [documentation, setDocumentation] = useState([]);
  const [showNormalView, setShowNormalView] = useState(true);
  const [selectedFunction, setSelectedFunction] = useState(null);

  useEffect(() => {
    async function load() {
      const response = await fetch("/template.json");
      const json = await response.json();

      console.log(json);
      console.log(Object.entries(json));

      setDocumentation(Object.entries(json));
    }

    load();
  }, []);

  if (showNormalView) {
    return (
      <>
        <Navbar />
        <HomeComponent
          main_package_name={main_package_name}
          documentation={documentation}
          setSelectedFunction={setSelectedFunction}
          setShowNormalView={setShowNormalView}
        />
      </>
    );
  } else {
    return (
      <>
        <Navbar />
        <FunctionComponentView
          main_package_name={main_package_name}
          function_obj={selectedFunction.function_obj}
          file_name={selectedFunction.file_name}
          onBack={() => setShowNormalView(true)}
        />
      </>
    );
  }
}

createRoot(document.getElementById("app")).render(<App />);
