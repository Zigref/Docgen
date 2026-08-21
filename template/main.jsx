import { useEffect, useState } from "preact/hooks";
import { render } from "preact";
import Prism from "prismjs";
import "prismjs/themes/prism-twilight.css";
import "prismjs/components/prism-zig";

const isFolder = (value) => {
    return typeof value === "object" && value !== null;
};

function make_this_only_components(components, namespaces, prefix = "") {
    const result = [];
    for (const component of components) {
        const full_name = prefix ? `${prefix}::${component.name}` : component.name;
        result.push({ ...component, name: full_name });
    }
    if (namespaces) {
        for (const namespace of namespaces) {
            const namespace_full_name = prefix ? `${prefix}::${namespace.name}` : namespace.name;
            result.push(...make_this_only_components(namespace.components, namespace.namespaces, namespace_full_name));
        }
    }
    return result;
}

function RenderDocumentation({ data }) {
    if (!data.components || data.components.length == 0) {
        return <>No documentation for this file!</>;
    }
    const only_components_list = make_this_only_components(data.components, data.namespaces);
    return (<>
        {
            only_components_list.map(component => {
                return (
                    <div className="box">
                        <h3><span className="component_type">{component.type}</span> <span className="component_name">{component.name}</span>:<span className="line_number">{component.line_number}</span></h3>

                        <p>{component.comment}</p>
                        {component.type === "test" ?
                            <pre><code className="language-zig">test {component.name}</code></pre>
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
    const [size_in_byte, set_size_in_byte] = useState(null);
    const [active_view, set_active_view] = useState("files");

    useEffect(() => {
        Prism.highlightAll();
    }, [selectedIndex]);
    useEffect(() => {
        fetch("/template.json.br")
            .then(r => {
                const size_byte = Number(r.headers.get("Content-Length"));
                const size_in_kib = size_byte / 1024;
                set_size_in_byte(size_in_kib.toFixed(2));
                return r.json();
            })
            .then(data => {
                setTree(data.metadata.project_tree);
                setCommitHash(data.metadata.commit_hash.slice(0, 10) + "...");
                setDataEntries(data.data);
            });
    }, []);

    return (
        <>
            <nav><a href="/" style={{ color: "white", textDecoration: "none" }}><span style={{ color: "yellow" }}>Zig</span>ref</a><input className="search_text" type="text" /></nav>
            <div class="content-wrapper">
                <aside id="side-side-bar">
                    <button class={`sidebar-btn ${active_view === "files" ? "active" : ""}`} onClick={() => set_active_view("files")}>
                        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-folder-open-icon lucide-folder-open"><path d="m6 14 1.5-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.54 6a2 2 0 0 1-1.95 1.5H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H18a2 2 0 0 1 2 2v2" /></svg>
                    </button>
                    <button class={`sidebar-btn ${active_view === "search" ? "active" : ""}`} onClick={() => set_active_view("search")}>
                        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-search-icon lucide-search"><path d="m21 21-4.34-4.34" /><circle cx="11" cy="11" r="8" /></svg>
                    </button>
                </aside>
                <aside id="sidebar">
                    {active_view === "files" ? (
                        <>
                            <h5 id="mention_title">File Explorer</h5>
                            {tree ? <TreeView tree={tree} onSelect={setSelectedIndex} /> : "Loading…"}
                        </>
                    ) : (
                        <>
                            <h5 id="mention_title">Search</h5>
                        </>
                    )}
                </aside>

                <main>
                    {selectedIndex !== null ? (
                        <>
                            <h2>Showing documentation for file: <span className="line_number">{selectedIndex.name}</span></h2>
                            {selectedIndex.value != null && dataEntries ? (
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
            <footer>
                <span>#{commit_hash} &nbsp;<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-file-archive-icon lucide-file-archive"><path d="M13.659 22H18a2 2 0 0 0 2-2V8a2.4 2.4 0 0 0-.706-1.706l-3.588-3.588A2.4 2.4 0 0 0 14 2H6a2 2 0 0 0-2 2v11.5" /><path d="M14 2v5a1 1 0 0 0 1 1h5" /><path d="M8 12v-1" /><path d="M8 18v-2" /><path d="M8 7V6" /><circle cx="8" cy="20" r="2" /></svg>{size_in_byte} KiB</span>
            </footer>
        </>
    );
}

render(<App />, document.getElementById("app"));