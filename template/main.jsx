import React from "react";
import { createRoot } from "react-dom/client";
import { useEffect, useState } from "react";

import Prism from "prismjs";

import "prismjs/themes/prism-okaidia.css";
import "prismjs/components/prism-zig";

function FunctionComponentView({
    main_package_name,
    function_obj,
    onBack,
}, file_name) {
    useEffect(() => {
        Prism.highlightAll();
    }, [function_obj]);

    return (
        <>
            <button onClick={onBack}>Back</button>

            <h1>Package {main_package_name}</h1>
            <h2>Function <span style={{ color: "#0e7496" }}>{function_obj.name}</span></h2>
            <h3>File <span style={{ color: "#0e7496" }}>{file_name}</span>:<span style={{ color: "#0e7496" }}>{function_obj.line_number}</span></h3>

            <a href="">Source code</a>

            <pre>
                <code className="language-zig">
                    {(function_obj.signature ?? "").trim()}
                </code>
            </pre>

            {function_obj.comment && (
                <>
                    <h3>Comment</h3>
                    <pre>{function_obj.comment}</pre>
                </>
            )}
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
                <h1>Package {main_package_name}</h1>

                <h2>Documentation:</h2>

                <hr />

                <h2>Functions:</h2>

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
                                            setSelectedFunction(x);
                                            setShowNormalView(false);
                                        }}
                                    >
                                        {x.name}
                                    </a>
                                    <br />
                                </>
                            )}
                        </React.Fragment>
                    ))
                )}

                <hr />

                <h2>Tests:</h2>

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
                    ))
                )}
            </>
        );
    }

    return (
        <FunctionComponentView
            main_package_name={main_package_name}
            function_obj={selectedFunction}
            onBack={() => setShowNormalView(true)}
        />
    );
}

createRoot(document.getElementById("app")).render(<App />);