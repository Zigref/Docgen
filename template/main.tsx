import React from "react";

function Node({ title, Content }: {
    title: string;
    Content: React.ComponentType;
}) {
    return
    <>
        <details>
            <summary>{title}</summary>
            <div><Content/></div>
        </details>
    </>
    ;
}

function DisplayFunction({name, comment, declaration, line_number}:{
    name: string;
    comment: string;
    declaration: string;
    line_number: number;
}) {
 return 
    <div>
        <h1>{name}</h1>
        <p>{comment}</p>
        <div>{declaration}</div>
        <h2>{line_number}</h2>
    </div>
;
}

function Home() {
    return <>
        <Node title="" Content={Node}/>
    </>;
}