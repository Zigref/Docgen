import React from "react";
import { createRoot } from "react-dom/client";
import { useEffect, useState } from "react";

import Prism from 'prismjs';

import 'prismjs/themes/prism-okaidia.css';

import 'prismjs/components/prism-zig';

function function_component_view(main_package_name, function_obj) {

    useEffect(() => {
        Prism.highlightAll();
    }, []);
    return <>
        <h1>Package {main_package_name}</h1>
        <h2>Function {function_obj.name}</h2>
        <a href="">Source code</a>

        <pre>
            <code className={`language-zig`}>
                {code.trim()}
            </code>
        </pre>
    </>
}





function App() {
    const main_package_name = "gh/zigistry/zigistry";

    const [documentation, setDocumentation] = useState([]);

    const [showNormalView, setShowNormalView] = useState(true);

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
                {
                    documentation.map(([file_name, file_data]) => {
                        return file_data.map((x) => {
                            return <>
                                <a onClick={() => {
                                    setShowNormalView = false;
                                }} className="function_name">
                                    {
                                        x.type === "function" ? x.name : ""
                                    }
                                </a>
                                <br />
                            </>;
                        });
                    })
                }
                <hr />
                <h2>Tests:</h2>
                {
                    documentation.map(([file_name, file_data]) => {
                        return file_data.map((x) => {
                            return <>
                                <a href="#" className="function_name">
                                    {
                                        x.type === "test" ? x.name : ""
                                    }
                                </a>
                                <br />
                            </>;
                        });
                    })
                }

            </>
        );
    } else {

    }
}

createRoot(document.getElementById("app")).render(<App />);