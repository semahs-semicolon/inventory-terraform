import pg from 'pg';
import { BedrockRuntimeClient, ConverseCommand } from "@aws-sdk/client-bedrock-runtime";
import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';

const ssmClient = new SSMClient();
const bedrockClient = new BedrockRuntimeClient();

const passwordResp  = await ssmClient.send(new GetParameterCommand({
    Name: process.env["DATABASE_PASSWORD_PARAM_NAME"],
    WithDecryption: true
}));


const pool = new pg.Pool({
    host: process.env["PGHOST"],
    user: process.env["PGUSER"],
    port: process.env["PGPORT"],
    password: passwordResp.Parameter.Value,
    database: process.env["PGDATABSAE"],
    max: 5,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
})




const buildCategories = async () => {
    const pgcategories = await pool.query("SELECT * FROM inventory.categories");

    let categories = [];
    let categoryMap = {};
    for (const row of pgcategories.rows) {
        const cid = row.category_id
        const name = row.name
        const pcid = row.parent_category_id;
        let categoryObj = {
            id: cid,
            name: name,
            parentId: pcid,
            children: []
        };
        categories.push(categoryObj);
        categoryMap[cid] = categoryObj;
    }

    for (const category of categories) {
        if (category.parentId == undefined) continue;
        category.parent = categoryMap[category.parentId];
    }

    let mapping = {}

    for (const category of categories) {
        mapping[category.id] = getCategoryName(category);
    }
    return mapping;
}

const getProduct = async (productId) => {
    return (await pool.query("SELECT * FROM inventory.products WHERE id = $1", [productId])).rows[0]
}
const persistChosen = async (productId, chosenId) => {
    return await pool.query("UPDATE inventory.products SET categoryAccepted = false, categoryId = $1 WHERE id = $2", [chosenId, productId])
}

const getCategoryName = (category) => {
    let name = category.name;
    category = category.parent;
    while (category != null) {
        name = name + " < " + category.name
        category = category.parent;
    }
    return name;
}

const chooseFinal = async (candidates, item) => {
    const tool_list = [
        {
            "toolSpec": {
                "name": "set_category",
                "description": "카테고리를 선택합니다.",
                "inputSchema": {
                    "json": {
                        "type": "object",
                        "properties": {
                            "category": {
                                "type": "string",
                                "description": "선택한 카테고리",
                                "enum": candidates.map(a => a.name)
                            },
                        },
                        "required": [
                            "category"
                        ]
                    }
                }
            }
        }
    ]

    
    const aiResponse = await bedrockClient.send(new ConverseCommand({
        modelId: process.env["MODEL_ID"],
        messages: [
            {
                "role": "user",
                "content": [
                    { "text": "당신에게 물품의 이름이 주어질 것입니다. 당신의 역할은 주어진 카테고리 목록에서 입력된 물품에 가장 잘 어울리는 카테고리를 하나 골라 그 이유와 함께 출력하는 것 입니다. Chain of Thought 기법을 사용하여 가장 적절한 카테고리를 찾으십시오. 그리고 set_category tool을 사용하여 생각에 기반한 카테고리 json을 생성하십시오."},
                    { "text": "카테고리 목록: " + candidates.map(a => a.name).join(", ")},
                    { "text": "### 입력: \n"+item+"\n\n"},
                    { "text": "### 출력: "}
                ],
            }
        ],
        inferenceConfig: {
            maxTokens: 2000,
            temperature: 0.7
        },
        toolConfig: {
            tools: tool_list,
            toolChoice: {
                tool: {
                    name: "set_category"
                }
            }
        }
    }));
    const blocks = aiResponse.output.message.content;
    console.log(aiResponse);

    for (const block of blocks) {
        if (block.toolUse != null) {
            const response = block.toolUse.input;
            return response.category;
        }
    }
    return undefined;
}

export const handler = async (event) => {
    const product = await getProduct(event.productId);
    const categories = await buildCategories();
    console.log(categories);
    console.log(product);

    let categoriesMod = [];
    for (const [id, category] of Object.entries(categories)) {
        categoriesMod.push({
            id: id,
            name: category
        })
    }

    // let questions = [];
    // for (const [id, category] of Object.entries(categories)) {
    //     // ask model
    //     if (category == "기타")
    //         questions.push(Promise.resolve({category: category, id: id, suitable: true}));
    //     else
    //         questions.push(askModelForSuitability(category, product.name)
    //             .then((val) => ({category: category, id: id, suitable: val})));
    // }
    // const allAnswers = await Promise.all(questions);
    // const candidates = allAnswers.filter(a => a.suitable);

    const chosen = await chooseFinal(categoriesMod, product.name); // Claude 3 Opus seem quite smart.
    
    const chosenCategory = categoriesMod.filter(a => a.name == chosen)[0];

    await persistChosen(event.productId, chosenCategory.id);
}
