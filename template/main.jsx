import { useEffect, useState } from "preact/hooks";
import { render } from "preact";
import Prism from "prismjs";
import "prismjs/themes/prism.css";
import "prismjs/components/prism-zig";

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
                            <pre><code className="language-zig">test "{component.name}"</code></pre>
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
                                <span style={{ display: "flex", alignItems: "center" }} className="file_folder_name">
                                    <svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-folder-icon lucide-folder"><path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z" /></svg>&nbsp;{name}&#47;
                                </span>
                            </summary>
                            <TreeView tree={value} onSelect={onSelect} />
                        </details>
                    ) : (
                        <span className="file_folder_name" style={{ display: "flex", alignItems: "center", cursor: "pointer" }}
                            onClick={() => onSelect({ name, value })}
                        >
                            &nbsp;
                            &nbsp;
                            <svg xmlns="http://www.w3.org/2000/svg" width={15} height={15} viewBox="0 0 153 140">
                                <g fill="#f7a41d">
                                    <g>
                                        <polygon points="46,22 28,44 19,30" />
                                        <polygon points="46,22 33,33 28,44 22,44 22,95 31,95 20,100 12,117 0,117 0,22" shape-rendering="crispEdges" />
                                        <polygon points="31,95 12,117 4,106" />
                                    </g>
                                    <g>
                                        <polygon points="56,22 62,36 37,44" />
                                        <polygon points="56,22 111,22 111,44 37,44 56,32" shape-rendering="crispEdges" />
                                        <polygon points="116,95 97,117 90,104" />
                                        <polygon points="116,95 100,104 97,117 42,117 42,95" shape-rendering="crispEdges" />
                                        <polygon points="150,0 52,117 3,140 101,22" />
                                    </g>
                                    <g>
                                        <polygon points="141,22 140,40 122,45" />
                                        <polygon points="153,22 153,117 106,117 120,105 125,95 131,95 131,45 122,45 132,36 141,22" shape-rendering="crispEdges" />
                                        <polygon points="125,95 130,110 106,117" />
                                    </g>
                                </g>
                            </svg>&nbsp;{name}
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
    const [commit_hash, setCommitHash] = useState();
    const [selectedIndex, setSelectedIndex] = useState(null);

    useEffect(() => {
        Prism.highlightAll();
    }, [selectedIndex]);
    useEffect(() => {
        fetch("/template.json.br")
            .then(r => r.json())
            .then(data => {
                setTree(data.metadata.project_tree);
                setCommitHash(data.metadata.commit_hash);
                setDataEntries(data.data);
            });
    }, []);

    return (
        <>
            <nav><a href="/">Zigref</a><input className="search_text" type="text" /><h4>{commit_hash}</h4></nav>
            <div style={{ display: "flex", gap: "2rem" }}>
                <aside style={{ minWidth: "250px" }}>
                    {tree ? <TreeView tree={tree} onSelect={setSelectedIndex} /> : "Loading…"}
                </aside>

                <main>
                    {selectedIndex !== null ? (
                        <>
                            <h2>Showing documentation for file: {selectedIndex.name}</h2>
                            {selectedIndex.value && dataEntries ? (
                                <RenderDocumentation key={selectedIndex.value} data={dataEntries[selectedIndex.value]} />
                            ) : (
                                <p>Select a file</p>
                            )}
                        </>
                    ) : (
                        <p>Select a file</p>
                    )}
                </main>
            </div>
        </>
    );
}

render(<App />, document.getElementById("app"));