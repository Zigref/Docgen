import { useEffect, useState } from "preact/hooks";
import { render } from "preact";
import Prism from "prismjs";
import "prismjs/themes/prism.css"; import "prismjs/components/prism-zig";

const isFolder = (value) => {
    return typeof value === "object" && value !== null;
};

function RenderDocumentation({ data }) {
    if (data.components.length == 0) {
        return <>No documentation for this file!</>;
    }
    return (<>
        {
            data.components.map(component => {
                return (
                    <div className="box">
                        <h3>{component.type} {component.name}</h3>
                        
                        <p>{component.comment}</p>
                        {component.type === "test" ?
                            <pre><code className="language-zig">test "{component.partial_definition}"</code></pre>
                            :
                            <pre><code className="language-zig">{component.partial_definition}</code></pre>
                        }
                    </div>
                );
            })
        }
    </>)
}

function TreeView({ tree, onSelect }) {
    const entries = Object.entries(tree).sort(
        ([, a], [, b]) => {
            return Number(isFolder(b)) - Number(isFolder(a));
        }
    );

    return (
        <ul>
            {entries.map(([name, value]) => (
                <div key={name}>
                    {isFolder(value) ? (
                        <details open>
                            <summary>
                                <span className="file_folder_name">
                                    {name}&#47;
                                </span>
                            </summary>
                            <TreeView tree={value} onSelect={onSelect} />
                        </details>
                    ) : (
                        <span
                            className="file_folder_name"
                            style={{ cursor: "pointer", textDecoration: "underline" }}
                            onClick={() => onSelect(value)}
                        >
                            {name}
                        </span>
                    )}
                </div>
            ))}
        </ul>
    );
}

function App() {
    const [tree, setTree] = useState();
    const [dataEntries, setDataEntries] = useState();
    const [selectedIndex, setSelectedIndex] = useState(null);

    useEffect(() => {
        Prism.highlightAll();
    }, [selectedIndex]);
    useEffect(() => {
        fetch("/template.json.br")
            .then(r => r.json())
            .then(data => {
                setTree(data.metadata.project_tree);
                setDataEntries(data.data);
            });
    }, []);

    return (
        <>
            <nav><a href="/">Zigref</a></nav>
            <div style={{ display: "flex", gap: "2rem" }}>
                <aside style={{ minWidth: "250px" }}>
                    <h2>Files</h2>
                    {tree ? <TreeView tree={tree} onSelect={setSelectedIndex} /> : "Loading…"}
                </aside>

                <main>
                    {selectedIndex !== null && dataEntries ? (
                        <RenderDocumentation data={dataEntries[selectedIndex]} />
                    ) : (
                        <p>Select a file</p>
                    )}
                </main>
            </div>
        </>
    );
}

render(<App />, document.getElementById("app"));