export interface ProblemDetails {
  type: string;
  title: string;
  status: number;
  code: string;
  requestId: string;
  detail?: string;
  fieldErrors?: Record<string, string[]>;
}

export function createProblemDetails(params: {
  status: number;
  code: string;
  title: string;
  requestId: string;
  type?: string;
  detail?: string;
  fieldErrors?: Record<string, string[]>;
}): ProblemDetails {
  const result: ProblemDetails = {
    type:
      params.type ??
      `https://api.rotinafamiliar.com/errors/${params.code.toLowerCase().replace(/_/g, '-')}`,
    title: params.title,
    status: params.status,
    code: params.code,
    requestId: params.requestId,
  };

  if (params.detail) {
    result.detail = params.detail;
  }

  if (params.fieldErrors && Object.keys(params.fieldErrors).length > 0) {
    result.fieldErrors = params.fieldErrors;
  }

  return result;
}
