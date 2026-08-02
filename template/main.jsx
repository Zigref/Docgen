import React from "react";
import { createRoot } from "react-dom/client";
import { useEffect, useState } from "react";

import Prism from "prismjs";

import "prismjs/themes/prism-okaidia.css";
import "prismjs/components/prism-zig";

function SectionCard({ title, type, documentation, onSelect }) {
  return (
    <article className="card">
      <header>
        <h3>{title}</h3>
      </header>
      <footer>
        <div className="item_grid">
          {documentation
            .flatMap(([file_name, file_data]) =>
              file_data.map((x, index) => ({ file_name, x, index })),
            )
            .filter(({ x }) => x.type === type)
            .map(({ file_name, x, index }) => (
              <a
                key={`${type}-${file_name}-${index}`}
                href="#"
                className="function_name"
                onClick={
                  onSelect
                    ? (e) => {
                        e.preventDefault();
                        onSelect(x, file_name);
                      }
                    : undefined
                }
              >
                {x.name}
              </a>
            ))}
        </div>
      </footer>
    </article>
  );
}

function DetailView({ main_package_name, type_label, obj, file_name, onBack }) {
  useEffect(() => {
    Prism.highlightAll();
  }, [obj]);

  return (
    <>
      <h1>Package {main_package_name}</h1>
      <hr className="main_hr" />

      <button onClick={onBack}>Back</button>
      <h2>
        {type_label} <span style={{ color: "#0e7496" }}>{obj.name}</span>
        &nbsp;<a href="#">[src]</a>
      </h2>

      <article className="card">
        <header>
          <h3>
            File <span style={{ color: "#0e7496" }}>{file_name}</span>:
            <span style={{ color: "#0e7496" }}>{obj.line_number}</span>
          </h3>
        </header>
        {obj.signature && (
          <footer>
            <pre>
              <code className="language-zig">{(obj.signature ?? "").trim()}</code>
            </pre>
          </footer>
        )}
      </article>

      {obj.comment && (
        <article className="card">
          <header>
            <h3>Comment</h3>
          </header>
          <footer>{obj.comment}</footer>
        </article>
      )}
    </>
  );
}

function HomeComponent({
  main_package_name,
  documentation,
  top_level_documentation,
  config,
  setSelectedFunction,
  setSelectedStruct,
  setSelectedTest,
  setShowNormalView,
}) {
  return (
    <>
      <h1>Package {main_package_name}</h1>

      <hr className="main_hr" />

      <article className="card">
        <header>
          <h3>Documentation</h3>
        </header>
        <footer>
          <pre>{top_level_documentation}</pre>
          {config && config.commit_hash !== "" && (
            <div style={{ marginTop: "10px", color: "#555" }}>
              commit: {config.commit_hash}
            </div>
          )}
        </footer>
      </article>

      <SectionCard
        title="Functions"
        type="function"
        documentation={documentation}
        onSelect={(x, file_name) => {
          setSelectedFunction({ function_obj: x, file_name });
          setSelectedStruct(null);
          setShowNormalView(false);
        }}
      />

      <SectionCard
        title="Structs"
        type="struct"
        documentation={documentation}
        onSelect={(x, file_name) => {
          setSelectedStruct({ struct_obj: x, file_name });
          setSelectedFunction(null);
          setShowNormalView(false);
        }}
      />

      <SectionCard
        title="Tests"
        type="test"
        documentation={documentation}
        onSelect={(x, file_name) => {
          setSelectedTest({ test_obj: x, file_name });
          setSelectedFunction(null);
          setSelectedStruct(null);
          setShowNormalView(false);
        }}
      />
    </>
  );
}

function Navbar() {
  return (
    <>
      <article className="card navbar">
        <header className="two">
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
  const [topLevelDocumentation, setTopLevelDocumentation] = useState("");
  const [config, setConfig] = useState(null);
  const [showNormalView, setShowNormalView] = useState(true);
  const [selectedFunction, setSelectedFunction] = useState(null);
  const [selectedStruct, setSelectedStruct] = useState(null);
  const [selectedTest, setSelectedTest] = useState(null);

  useEffect(() => {
    async function load() {
      const response = await fetch("/template.json");
      const json = await response.json();

      console.log(json);

      setDocumentation(Object.entries(json.files));
      setTopLevelDocumentation(json.top_level_documentation);
      setConfig(json.config);
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
          top_level_documentation={topLevelDocumentation}
          config={config}
          setSelectedFunction={setSelectedFunction}
          setSelectedStruct={setSelectedStruct}
          setSelectedTest={setSelectedTest}
          setShowNormalView={setShowNormalView}
        />
      </>
    );
  } else if (selectedStruct) {
    return (
      <>
        <Navbar />
        <DetailView
          main_package_name={main_package_name}
          type_label="Struct"
          obj={selectedStruct.struct_obj}
          file_name={selectedStruct.file_name}
          onBack={() => setShowNormalView(true)}
        />
      </>
    );
  } else if (selectedTest) {
    return (
      <>
        <Navbar />
        <DetailView
          main_package_name={main_package_name}
          type_label="Test"
          obj={selectedTest.test_obj}
          file_name={selectedTest.file_name}
          onBack={() => setShowNormalView(true)}
        />
      </>
    );
  } else {
    return (
      <>
        <Navbar />
        <DetailView
          main_package_name={main_package_name}
          type_label="Function"
          obj={selectedFunction.function_obj}
          file_name={selectedFunction.file_name}
          onBack={() => setShowNormalView(true)}
        />
      </>
    );
  }
}

createRoot(document.getElementById("app")).render(<App />);
