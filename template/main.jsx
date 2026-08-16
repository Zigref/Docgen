import { useEffect, useState } from "preact/hooks";
import { render } from "preact";

const isFolder = (value) => {
    return typeof value === "object"
};

function TreeView({ tree }) {

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
                            <TreeView tree={value} />
                        </details>
                    ) : (
                        <span className="file_folder_name">
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

    useEffect(() => {
        fetch("/template.json")
            .then(r => r.json())
            .then(data => setTree(data.metadata.project_tree));
    }, []);

    return (
        <>
            <nav><a href="/">Zigref</a></nav>
            <div style={{ display: "flex" }}>
                <aside>
                    <h2>Files</h2>
                    {tree ? <TreeView tree={tree} /> : "Loading…"}
                </aside>

                <main>Select a file</main>
            </div>
        </>
    );
}

render(<App />, document.getElementById("app"));